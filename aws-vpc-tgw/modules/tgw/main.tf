variable "tgw_name" {
  type        = string
  description = "The name of the Transit Gateway"
}

variable "amazon_side_asn" {
  type        = number
  description = "The ASN for the Amazon side of the Transit Gateway"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A mapping of tags to assign to the Transit Gateway"
}

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

output "tgw_id" {
  value = aws_ec2_transit_gateway.tgw.id
}
