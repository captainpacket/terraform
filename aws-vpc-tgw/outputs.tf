output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "subnet_ids" {
  value = values(aws_subnet.subnet)[*].id
}

output "vpc_cidr_block" {
  value = aws_vpc.vpc.cidr_block
}

output "subnet_cidr_blocks" {
  value = values(aws_subnet.subnet)[*].cidr_block
}
