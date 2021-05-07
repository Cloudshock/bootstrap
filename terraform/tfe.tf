################################################################################
#
# bootstrap
#   A Terraform project to provision the resources needed to deploy the project.
#
# tfe.tf
#   Defines the Terraform Cloud resources.
#
################################################################################

# Configuring the tfe provider, the token attribute value is provided via the
#   TFE_TOKEN environment variable.
provider "tfe" {
  hostname = "app.terraform.io"
}

resource "tfe_workspace" "bootstrap" {
  name               = "bootstrap"
  description        = "Bootstraps Terraform Cloud and GCP resources"
  organization       = "cloudshock"
  allow_destroy_plan = false
  terraform_version  = "0.15.1"
  queue_all_runs     = false
  working_directory  = "terraform/"

  trigger_prefixes = [ 
    "terraform/",
  ]

  vcs_repo {
    identifier     = "cloudshock/bootstrap"
    branch         = "main"
    oauth_token_id = var.terraform_cloud_oauth_token_id
  }
}
