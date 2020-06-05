output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.main_vpc.vpc_id
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = module.main_vpc.name
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.main_vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.main_vpc.public_subnets
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.main_vpc.database_subnets
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = aws_eip.main_vpc_nat_gateway.*.public_ip
}

output "database_subnet_arns" {
  value = module.main_vpc.database_subnet_arns
}

output "database_subnet_group" {
  value = module.main_vpc.database_subnet_group
}
