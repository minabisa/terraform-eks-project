output "node_group_arns" {
  description = "ARNs of the created node groups"
  value       = { for k, v in aws_eks_node_group.this : k => v.arn }
}

output "node_group_statuses" {
  description = "Status of each node group"
  value       = { for k, v in aws_eks_node_group.this : k => v.status }
}

output "node_group_ids" {
  description = "IDs of the created node groups"
  value       = { for k, v in aws_eks_node_group.this : k => v.id }
}
