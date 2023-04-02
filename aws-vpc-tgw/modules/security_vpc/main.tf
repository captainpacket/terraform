variable "name" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "transit_gateway_id" {
  type = string
}

data "aws_ami" "palo_alto_fw" {
  most_recent = true

  filter {
    name   = "name"
    values = ["PA-VM-AWS-10.0*"]
  }

  filter {
    name   = "product-code"
    values = ["6njl1pau431dv1qxipg63mvah"]
  }

  owners = ["679593333241"] # Palo Alto Networks AWS Marketplace account ID
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

variable "key_pair_name" {
  type = string
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_ec2_transit_gateway_vpc_attachment" "tgw_attachment" {
  vpc_id             = aws_vpc.vpc.id
  subnet_ids         = [for subnet in aws_subnet.subnet : subnet.id if subnet.tags["Type"] == "tgw"]
  transit_gateway_id = var.transit_gateway_id
}

output "tgw_attachment_id" {
  value = aws_ec2_transit_gateway_vpc_attachment.tgw_attachment.id
}

resource "aws_subnet" "subnet" {
  for_each = {
    for count in range(length(local.availability_zones) * 2):
      "${count}" => {
        cidr_block = cidrsubnet(var.cidr_block, 8, count)
        availability_zone = element(local.availability_zones, count % length(local.availability_zones))
        ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count)
        assign_ipv6_address_on_creation = true
        name = "${var.name}-subnet-${element(local.availability_zones, count % length(local.availability_zones))}-${count + 1}"
        type = count < length(local.availability_zones) ? "tgw" : "palo_alto"
      }
  }

  vpc_id = aws_vpc.vpc.id
  cidr_block = each.value.cidr_block
  availability_zone = each.value.availability_zone
  ipv6_cidr_block = each.value.ipv6_cidr_block
  assign_ipv6_address_on_creation = each.value.assign_ipv6_address_on_creation

  tags = {
    Name = each.value.name
    Type = each.value.type
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count = length(local.availability_zones)

  subnet_id      = aws_subnet.subnet[count.index * 2].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  count = length(local.availability_zones)

  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  count = length(local.availability_zones)

  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.subnet[format("%d", count.index * 2)].id
}

resource "aws_route_table" "nat_route_table" {
  count = length(local.availability_zones)

  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "nat_route" {
  count = length(local.availability_zones)

  route_table_id         = aws_route_table.nat_route_table[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[count.index].id
}

resource "aws_route_table_association" "nat_route_table_association" {
  count = length(local.availability_zones)

  subnet_id      = aws_subnet.subnet[format("%d", count.index * 2 + 1)].id
  route_table_id = aws_route_table.nat_route_table[count.index].id
}

resource "aws_instance" "palo_alto_fw" {
  count = length(local.availability_zones)

  ami           = data.aws_ami.palo_alto_fw.id
  instance_type = "m5.xlarge" # Update the instance type if needed
  subnet_id     = [for subnet in aws_subnet.subnet : subnet.id if subnet.tags["Type"] == "palo_alto"][count.index]
  key_name      = var.key_pair_name

  tags = {
    Name = "palo-alto-fw-${count.index + 1}"
  }
}
