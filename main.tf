provider "aws" {
  region = var.aws_region
}

# Data source to get availability zones
data "aws_availability_zones" "available" {}

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.2"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["${cidrsubnet(var.vpc_cidr, 8, 0)}", "${cidrsubnet(var.vpc_cidr, 8, 1)}"]
  public_subnets  = ["${cidrsubnet(var.vpc_cidr, 8, 128)}", "${cidrsubnet(var.vpc_cidr, 8, 129)}"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    "Terraform"   = "true"
    "Environment" = terraform.workspace
  }
}

# -----------------------------------------------------------------------------
# EKS Cluster Module
# -----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = "${var.cluster_name}-cluster"
  cluster_version = "1.28"
  enable_irsa = true
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    one = {
      name           = "${var.cluster_name}-node-group"
      instance_types = var.instance_types
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }

  tags = {
    "Terraform"   = "true"
    "Environment" = terraform.workspace
  }
}

# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "${var.cluster_name}-app-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    "Terraform"   = "true"
    "Environment" = terraform.workspace
  }
}

# -----------------------------------------------------------------------------
# RDS Database Module
# -----------------------------------------------------------------------------
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.4.0"

  identifier = "${var.cluster_name}-db"

  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_encrypted    = true
  
  db_name              = "appdb"
  username             = "admin"
  # TODO: Refactor to use AWS Secrets Manager before production deployment.
  password             = "aSecurePassword123" 
  port                 = "5432"

  vpc_security_group_ids = [module.eks.cluster_security_group_id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  
  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = {
    "Terraform"   = "true"
    "Environment" = terraform.workspace
  }
}
