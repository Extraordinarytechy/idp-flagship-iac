# ---------------------------------------------------------------------------
# Core Infrastructure Outputs
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnets"
  value       = module.vpc.public_subnets
}

output "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster API Server endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "EKS Cluster security group ID"
  value       = module.eks.cluster_security_group_id
}

output "ecr_repository_url" {
  description = "ECR Repository URI"
  value       = aws_ecr_repository.app.repository_url
}

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
}

# ---------------------------------------------------------------------------
# IAM Roles Outputs
# ---------------------------------------------------------------------------

output "rds_snapshot_role_arn" {
  description = "IAM role ARN for the RDS Snapshot Manager"
  value       = aws_iam_role.rds_snapshot_role.arn
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions OIDC access"
  value       = aws_iam_role.github_actions_role.arn
}
