variable "count_client_instance" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

###
# provider settings
###

provider "aws" {
  region                  = "eu-central-1"
  shared_credentials_file = "./keys/aws/key"
  profile                 = "default"
}

###
# resources
###

## key pair to access master instance
resource "aws_key_pair" "master_key" {
  key_name   = "master_key"
  public_key = file("./keys/ssh/id_master_rsa.pub")
}

resource "aws_key_pair" "client_key" {
  key_name   = "client_key"
  public_key = file("./keys/ssh/id_client_rsa.pub")
}

## master instance
resource "aws_instance" "master" {
  key_name      = aws_key_pair.master_key.key_name
  ami           = "ami-0502e817a62226e03"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.allow_ingress.id, aws_security_group.allow_egress.id]

  tags = {
    Name = "Master"
  }
}

resource "aws_instance" "client" {
  count         = var.count_client_instance
  key_name      = aws_key_pair.client_key.key_name
  ami           = "ami-0502e817a62226e03"
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.allow_ingress.id, aws_security_group.allow_egress.id]

  tags = {
    Name = "Client"
  }
}

## ssh sg-s
resource "aws_security_group" "allow_ingress" {
  vpc_id = data.aws_vpc.default.id

  name        = "allow_ingress"
  description = "allow_ingress"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_egress" {
  vpc_id = data.aws_vpc.default.id

  name        = "allow_egress"
  description = "allow_egress"
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## eip for master ec2
resource "aws_eip" "ip_master" {
  vpc      = true
  instance = aws_instance.master.id
}

## local inventory file
resource "local_file" "save_inventory" {
  content  = data.template_file.inventory.rendered
  filename = "./inventory"
}

###
# data
###

data "template_file" "inventory" {
  template = file(".terraform/_templates/inventory.tpl")

  vars = {
    user = "ubuntu"
    host = join("", ["master ansible host=", aws_eip.ip_master.public_ip])
  }
}

# use a default aws vpc
data "aws_vpc" "default" {
  default = true
}
