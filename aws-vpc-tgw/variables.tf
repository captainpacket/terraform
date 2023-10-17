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

variable "instances_per_subnet" {
  type        = number
  default     = 3
  description = "Number of EC2 instances per subnet"
} 

# Define the number of VPCs to create as a variable
variable "num_vpcs" {
  description = "Number of VPCs to deploy"
  type = number
  default = 2
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

variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the Transit Gateway"
  default     = {}
}

variable "subnets" {
  type        = map(number)
  description = "Number of subnets to create per availability zone"
  default = {
    "a" = 2,
    "b" = 2
  }
}

variable "fwd_username" {
  description = "The Forward Networks username"
  type        = string
}

variable "fwd_password" {
  description = "The Forward Networks Password"
  type        = string
  sensitive   = true
}

variable "network_id" {
  description = "The Forward Networks Network ID"
  type	      = string
}

variable "fwd_apphost" {
  description = "The Forward Networks Password"
  type        = string
  default     = "fwd.app"
}

variable "setup_id" {
  description = "The Forward Networks Setup ID"
  type	      = string
  default      = "cloud_collect"
}
