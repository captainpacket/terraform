data "http" "icanhazip" {
  url = "http://ipv4.icanhazip.com"
}

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

resource "aws_lb" "gwlb" {
  name               = "${var.name}-gwlb"
  load_balancer_type = "gateway"

  subnet_mapping {
    subnet_id = aws_subnet.subnet[0].id
  }

  subnet_mapping {
    subnet_id = aws_subnet.subnet[1].id
  }

  tags = {
    Name = "${var.name}-gwlb"
  }
}

resource "aws_lb_target_group" "gwlb_tg" {
  name     = "${var.name}-gwlb-tg"
  port     = 6081
  protocol = "GENEVE"
  target_type = "instance"
  vpc_id = aws_vpc.vpc.id

  health_check {
    port     = "traffic-port"
    protocol = "TCP"
  }
}

resource "aws_lb_target_group_attachment" "gwlb_tg_attachment" {
  count = length(local.availability_zones)

  target_group_arn = aws_lb_target_group.gwlb_tg.arn
  target_id        = aws_instance.palo_alto_fw[count.index].id
  port             = 6081
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
    for count in range(length(local.availability_zones) * 4):
      "${count}" => {
        cidr_block = cidrsubnet(var.cidr_block, 8, count)
        availability_zone = element(local.availability_zones, count % length(local.availability_zones))
        ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count)
        assign_ipv6_address_on_creation = true
        name = "${var.name}-subnet-${element(local.availability_zones, count % length(local.availability_zones))}-${count + 1}"
        type = count < 2 ? "palo_alto" : count < 4 ? "palo_alto_gwlb" : count < 6 ? "nat_gw" : "tgw"
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

  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  count = length(local.availability_zones)

  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = [for subnet in aws_subnet.subnet : subnet.id if subnet.tags["Type"] == "nat_gw"][count.index]
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

resource "aws_network_interface" "palo_alto_primary_eni" {
  count = length(local.availability_zones)

  subnet_id = [for subnet in aws_subnet.subnet : subnet.id if subnet.tags["Type"] == "palo_alto"][count.index]
  security_groups = [aws_security_group.palo_alto_mgmt_sg.id]

  tags = {
    Name = "palo-alto-fw-primary-eni-${count.index + 1}"
  }
}

resource "aws_network_interface" "palo_alto_secondary_eni" {
  count = length(local.availability_zones)

  subnet_id = [for subnet in aws_subnet.subnet : subnet.id if subnet.tags["Type"] == "palo_alto_gwlb"][count.index]

  tags = {
    Name = "palo-alto-fw-secondary-eni-${count.index + 1}"
  }
}

variable "secret" {
  type        = string
  description = "Generated secret for Palo Alto firewall user data"
}

resource "aws_instance" "palo_alto_fw" {
  count = length(local.availability_zones)

  ami           = data.aws_ami.palo_alto_fw.id
  instance_type = "m5.xlarge" # Update the instance type if needed
  user_data = "mgmt-interface-swap=enable\nplugin-op-commands=aws-gwlb-inspect:enable\nmy_secret=${var.secret}\n"
  key_name      = var.key_pair_name

  tags = {
    Name = "palo-alto-fw-${count.index + 1}"
  }

  network_interface {
    network_interface_id = aws_network_interface.palo_alto_primary_eni[count.index].id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.palo_alto_secondary_eni[count.index].id
    device_index         = 1
  }
}

resource "aws_eip" "palo_alto_mgmt_eip" {
  count = length(aws_instance.palo_alto_fw)

  domain = "vpc"

  tags = {
    Name = "palo-alto-fw-mgmt-eip-${count.index + 1}"
  }
}

output "palo_alto_mgmt_eips" {
  description = "Elastic IPs for Palo Alto management interfaces"
  value       = aws_eip.palo_alto_mgmt_eip.*.public_ip
}

resource "aws_eip_association" "palo_alto_mgmt_eip_association" {
  count = length(aws_instance.palo_alto_fw)

  network_interface_id = aws_instance.palo_alto_fw[count.index].primary_network_interface_id
  allocation_id = aws_eip.palo_alto_mgmt_eip[count.index].id
}

resource "aws_security_group" "palo_alto_mgmt_sg" {
  name_prefix = "palo-alto-mgmt-sg"
  vpc_id      = aws_vpc.vpc.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["70.120.129.118/32"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["70.120.129.118/32"]
  }
  
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["70.120.129.118/32"]
  }
  
  tags = {
    Name = "palo-alto-mgmt-sg"
  }
}
