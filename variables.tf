
variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}
variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "instance_types" {
  description = "List of EC2 instance types for the EKS node group."
  type        = list(string)
}

variable "db_instance_class" {
  description = "The instance class for the RDS database."
  type        = string
}

variable "db_allocated_storage" {
  description = "The allocated storage for the RDS database."
  type        = number
}
