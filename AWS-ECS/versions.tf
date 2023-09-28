terraform {
  required_version = "~> 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}
provider "aws" {
  region = "ap-south-1"
  access_key = "<AWS_ACCESS_KEY>"
  secret_key = "<AWS_SECRET_KEY>"

  default_tags {
    tags = {
      Name = "Web-App-on-ECS-Fargate"
    }
  }
}