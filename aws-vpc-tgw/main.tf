terraform {
  required_providers {
    forwardnetworks = {
      source  = "fracticated/forwardnetworks"
      version = "0.0.1"
    }
  }
  required_version = ">= 0.13"
}

provider "forwardnetworks" {
  username = var.fwd_username
  password = var.fwd_password
  #apphost = var.fwd_apphost
  insecure = false
}

provider "aws" {
  region = var.region
}

module "iam_role" {
  source = "./modules/iam_role"
  role_name = var.setup_id
  external_id = data.forwardnetworks_externalid.example.external_id
}

module "security_vpc" {
  source = "./modules/security_vpc"

  cidr_block = cidrsubnet(var.global_cidr, 4, var.num_vpcs + 1)
  name       = "security-vpc"
  key_pair_name = aws_key_pair.ssh_key.key_name
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  secret = random_string.my_secret.result
}

module "vpcs" {
  source = "./modules/vpc"

  count = var.num_vpcs

  cidr_block = cidrsubnet(var.global_cidr, 4, count.index)
  name       = "vpc-${count.index}"
  subnet_counts = var.subnets
  key_pair_name = aws_key_pair.ssh_key.key_name
}

data "forwardnetworks_externalid" "example" {
  network_id = var.network_id
}

resource "forwardnetworks_cloud" "example" {
  network_id     = var.network_id
  name           = var.setup_id
  type           = "AWS"
  rolearn	 = [module.iam_role.role_arn]
  account_id	 = [data.aws_caller_identity.current.account_id]
  account_name   = [var.setup_id]

  regions = [var.region]
}

data "aws_caller_identity" "current" {}

resource "random_string" "my_secret" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric  = true
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create an RSA key pair
resource "aws_key_pair" "ssh_key" {
  key_name   = "my_ssh_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Create the Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description = var.tgw_name
  amazon_side_asn = var.amazon_side_asn
  auto_accept_shared_attachments   = "disable"
  default_route_table_association  = "disable"
  default_route_table_propagation  = "disable"

  tags = merge(
    {
      "Name" = var.tgw_name
    },
    var.tags
  )
}

# Create a peering attachment for each VPC to the Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
  count = var.num_vpcs

  subnet_ids = module.vpcs[count.index].tgw_attach_subnet_ids
  vpc_id     = module.vpcs[count.index].vpc_id
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
}

resource "aws_ec2_transit_gateway_route_table" "tgw_route_table" {
  count = var.num_vpcs

  transit_gateway_id = aws_ec2_transit_gateway.tgw.id

  tags = {
    Name = "tgw-route-table-${count.index}"
  }
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_rt_assoc" {
  count = var.num_vpcs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[count.index].id
}

# Output the Transit Gateway ID and the VPC attachment IDs



output "tgw_route_table_ids" {
  value = aws_ec2_transit_gateway_route_table.tgw_route_table[*].id
}

output "vpc_attachment_ids" {
  value = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[*].id
}

output "palo_alto_mgmt_eips" {
  description = "Elastic IPs for Palo Alto management interfaces"
  value       = module.security_vpc.palo_alto_mgmt_eips
}


output "external_service_role_arn" {
  value       = module.iam_role.role_arn
  description = "ARN of the IAM role created for the external service"
}

output "my_secret" {
  value     = random_string.my_secret.result
  sensitive = true
}

output "private_key" {
  sensitive = true
  value = tls_private_key.ssh_key.private_key_pem
}

