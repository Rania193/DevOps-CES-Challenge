output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ip" {
  description = "Public IP of the NAT Gateway"
  value       = aws_eip.nat[0].public_ip
}

output "nlb_eip_id" {
  description = "Allocation ID of NLB Elastic IP (for ingress-nginx)"
  value       = aws_eip.nlb[0].id
}

output "nlb_eip_ip" {
  description = "Static public IP for your load balancer - use in DuckDNS"
  value       = aws_eip.nlb[0].public_ip
}
