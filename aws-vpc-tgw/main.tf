# Configure the AWS provider with the specified region

terraform {
  required_providers {
    forwardnetworks = {
      source  = "local/hashicorp/forwardnetworks"
      version = ">= 1.0.0"
    }
  }
  required_version = ">= 0.13"
}

provider "forwardnetworks" {
  username = "6o4e-eiidn-xfum"
  password = "lvbwxalmp634encqezmks6w4k5dfegqh"
  base_url = "https://fwd.app"
}

provider "aws" {
  region = var.region
}

data "forwardnetworks_externalid" "example" {
  network_id = "155308"
}

variable "instances_per_subnet" {
  type        = number
  default     = 1
  description = "Number of EC2 instances per subnet"
}

variable "key_pair_file" {
  type        = string
  default     = "id_rsa.pub"
  description = "Path to the public key file for the key pair"
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

# Create a module for VPCs
module "vpcs" {
  source = "./modules/vpc"

  count = var.num_vpcs

  cidr_block = cidrsubnet(var.global_cidr, 4, count.index)
  name       = "vpc-${count.index}"
  subnet_counts = var.subnets
  key_pair_name = aws_key_pair.example.key_name
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

resource "aws_key_pair" "example" {
  key_name   = "example-key"
  public_key = file(var.key_pair_file)
}

resource "random_string" "my_secret" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric  = true
}

resource "aws_ec2_transit_gateway_route_table_association" "tgw_rt_assoc" {
  count = var.num_vpcs

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[count.index].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.tgw_route_table[count.index].id
}

# Output the Transit Gateway ID and the VPC attachment IDs

module "security_vpc" {
  source = "./modules/security_vpc"

  cidr_block = cidrsubnet(var.global_cidr, 4, var.num_vpcs + 1)
  name       = "security-vpc"
  key_pair_name = aws_key_pair.example.key_name
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  secret = random_string.my_secret.result
}

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

module "iam_role" {
  source = "./modules/iam_role"
  role_name = "Forward_Networks"
  external_id = data.forwardnetworks_externalid.example.external_id
}

output "external_service_role_arn" {
  value       = module.iam_role.role_arn
  description = "ARN of the IAM role created for the external service"
}

output "my_secret" {
  value     = random_string.my_secret.result
  sensitive = true
}