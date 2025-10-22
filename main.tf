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

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = "1"
  }

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

  cluster_timeouts = {
    create = "60m"
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = concat(module.vpc.private_subnets, module.vpc.public_subnets)

  eks_managed_node_groups = {
    one = {
      name           = "${var.cluster_name}-node-group"
      instance_types = var.instance_types
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      subnet_ids = module.vpc.private_subnets
      
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
# RDS Security Group 
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    "Terraform"   = "true"
    "Environment" = terraform.workspace
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.cluster_name}-rds-sg"
  description = "RDS security group within same VPC as EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
  from_port   = 5432
  to_port     = 5432
  protocol    = "tcp"
  security_groups = [module.eks.cluster_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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
  engine_version       = "15"
  family               = "postgres15"
  instance_class       = var.db_instance_class
  allocated_storage    = var.db_allocated_storage
  storage_encrypted    = true
  
  db_name              = "appdb"
  username             = "dbadmin"
  password             = "aSecurePassword123" 
  port                 = "5432"
  db_subnet_group_name = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  backup_retention_period = 0
  skip_final_snapshot     = true

  tags = {
    "Terraform"   = "true"
    "Environment" = terraform.workspace
  }
}
