# Define the region as a variable
variable "region" {
  type        = string
  description = "The AWS region where the VPCs will be created"
  validation {
    condition     = can(regex("^[a-z]{2}(-gov)?-[a-z]+-[0-9]$", var.region))
    error_message = "Invalid region format. The region should be in the format of 'us-east-1', 'us-gov-west-1', etc."
  }
}

variable "global_cidr" {
  type        = string
  description = "The CIDR block for the VPCs"
}

# Define the number of VPCs to create as a variable
variable "num_vpcs" {
  type = number
}

variable "tgw_name" {
  type        = string
  description = "The name of the Transit Gateway"
}

variable "amazon_side_asn" {
  type        = number
  description = "The ASN for the Amazon side of the Transit Gateway"
}

variable "subnets" {
  type        = map(number)
  description = "Number of subnets to create per availability zone"
  default     = {
    "a" = 1
    "b" = 1
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of tags to assign to the Transit Gateway"
}

# Configure the AWS provider with the specified region
provider "aws" {
  region = var.region
}

# Create the Transit Gateway
resource "aws_ec2_transit_gateway" "tgw" {
  description = var.tgw_name
  amazon_side_asn = var.amazon_side_asn

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
}

# Create a peering attachment for each VPC to the Transit Gateway
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_attachment" {
  count = var.num_vpcs

  subnet_ids = module.vpcs[count.index].subnet_ids
  vpc_id     = module.vpcs[count.index].vpc_id
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
}


# Output the Transit Gateway ID and the VPC attachment IDs

output "vpc_attachment_ids" {
  value = aws_ec2_transit_gateway_vpc_attachment.vpc_attachment[*].id
}