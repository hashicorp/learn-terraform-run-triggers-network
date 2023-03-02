# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "app_instance_security_group_ids" {
  description = "Security groups for instances serving HTTP/HTTPS traffic"
  value       = [aws_security_group.private.id]
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public.*.id
}

output "private_subnet_ids" {
  description = "Private subnets IDs"
  value       = aws_subnet.private.*.id
}

output "lb_target_group_http_arn" {
  description = "ARN of load balancer HTTP target group"
  value       = aws_lb_target_group.http.arn
}

# output lb_target_group_https_arn {
#   description = "ARN of load balancer HTTPS target group"
#   value       = aws_lb_target_group.https.arn
# }

output "project_tag" {
  description = "Tag for aws resources in this project"
  value       = var.project_tag
}

output "public_dns_name" {
  value = aws_lb.vpc.dns_name
}
