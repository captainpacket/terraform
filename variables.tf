variable "region" {
  type        = string
  description = "The AWS region where the VPCs will be created"
  default = "us-west-2"
}

variable "global_cidr" {
  type        = string
  description = "The CIDR block for the VPCs"
  default = "10.1.0.0/16"
}

# Define the number of VPCs to create as a variable
variable "num_vpcs" {
  description = "Number of VPCs to deploy"
  type = number
  default = 4
}

variable "tgw_name" {
  type        = string
  description = "The name of the Transit Gateway"
  default = "tgw"
}

variable "amazon_side_asn" {
  type        = number
  description = "The ASN for the Amazon side of the Transit Gateway"
  default = 64512
}

variable "subnets" {
  type        = map(number)
  description = "Number of subnets to create per availability zone"
  default = {
    "a" = 4
    "b" = 4
  }
}
