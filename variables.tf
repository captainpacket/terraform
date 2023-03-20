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
