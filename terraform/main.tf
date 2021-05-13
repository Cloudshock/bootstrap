################################################################################
#
# bootstrap
#   A Terraform project to provision the resources needed to deploy the project.
#
# main.tf
#   Defines the Terraform settings and required providers.
#
################################################################################

terraform {
  required_version = "~> 0.15.0"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.25.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 3.67"
    }
  }

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "cloudshock"

    workspaces {
      name = "bootstrap"
    }
  }
}
