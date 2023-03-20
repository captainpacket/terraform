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

output "ipv6_cidr_block" {
  value = aws_vpc.vpc.ipv6_cidr_block
}

output "subnet_ipv6_cidr_blocks" {
  value = values(aws_subnet.subnet)[*].ipv6_cidr_block
}

output "vpc_security_group_id" {
  value = aws_security_group.vpc_sg.id
}

output "nat_gateway_ids" {
  value = aws_nat_gateway.nat_gateway[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}
