terraform {
  backend "s3" {
    bucket         = "backend-proj-terra-form"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
