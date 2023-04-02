variable "instances_per_subnet" {
  type        = number
  default     = 1
  description = "Number of EC2 instances per subnet"
}

variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "subnet_counts" {
  type = map(number)
}

variable "key_pair_name" {
  type        = string
  description = "Name of the EC2 key pair to be used for the instances"
}

resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = var.name
  }

  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  assign_generated_ipv6_cidr_block = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  total_subnet_count = sum(values(var.subnet_counts))
  tgw_attach_subnet_count = length(local.availability_zones) # Add this line
}

resource "aws_subnet" "subnet" {
  for_each = {
    for count in range(local.total_subnet_count + local.tgw_attach_subnet_count):
      "${count}" => {
        cidr_block = cidrsubnet(var.cidr_block, 8, count)
        availability_zone = element(local.availability_zones, count % length(local.availability_zones))
        ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count)
        assign_ipv6_address_on_creation = true
        name = "${var.name}-subnet-${element(local.availability_zones, count % length(local.availability_zones))}-${count + 1}"
      }
  }

  vpc_id = aws_vpc.vpc.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone
  ipv6_cidr_block = each.value.ipv6_cidr_block
  assign_ipv6_address_on_creation = each.value.assign_ipv6_address_on_creation

  tags = {
    Name = each.value.name
  }
}

resource "aws_security_group" "ssh_sg" {
  name        = "${var.name}-ssh-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "subnet_instance" {
  for_each = {
    for idx in range(local.total_subnet_count * var.instances_per_subnet) :
    idx => {
      subnet_id = values(aws_subnet.subnet)[idx / var.instances_per_subnet].id
    }
  }

  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t4g.nano" # This is one of the cheapest instance types available
  subnet_id     = each.value.subnet_id
  key_name      = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ssh_sg.id]

   tags = {
    Name          = "${var.name}-vpc-subnet-${each.value.subnet_id}-instance-${substr(each.key, -1, 1)}"
    VPC           = var.name
    Subnet_ID     = each.value.subnet_id
    Instance_Num  = substr(each.key, -1, 1)
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "subnet_ids" {
  value = values(aws_subnet.subnet)[*].id
}

output "tgw_attach_subnet_ids" { 
  value = slice(values(aws_subnet.subnet), local.total_subnet_count, local.total_subnet_count + local.tgw_attach_subnet_count)[*].id
}

output "subnet_instance_ids" {
  value = values(aws_instance.subnet_instance)[*].id
}
