terraform {
  backend "s3" {
    bucket         = "backend-proj-terra-form"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = "terraform-state-lock"
    encrypt        = true
  }
}
