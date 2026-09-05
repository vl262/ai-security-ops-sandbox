terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Používá AWS CLI profil nastavený pro Workload account.
# Nastav ho předem, např.:
#   aws configure --profile vl-workload
# a spusť terraform s AWS_PROFILE=vl-workload (viz README v této složce).
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
