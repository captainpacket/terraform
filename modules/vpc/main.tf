variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "subnet_counts" {
  type = map(number)
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
}

resource "aws_subnet" "subnet" {
  for_each = {
    for count in range(local.total_subnet_count):
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

output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "subnet_ids" {
  value = values(aws_subnet.subnet)[*].id
}