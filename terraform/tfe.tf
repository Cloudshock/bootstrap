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

resource "tfe_workspace" "gcp_project" {
  for_each = toset(var.gcp_projects)

  name               = "gcp-project-${each.value}"
  description        = "Configures GCP Project ${each.value}"
  organization       = "cloudshock"
  allow_destroy_plan = false
  terraform_version  = "0.15.1"
  queue_all_runs     = false
}

resource "tfe_variable" "google_credentials" {
  for_each = toset(var.gcp_projects)

  key          = "GOOGLE_CREDENTIALS"
  value        = base64decode(var.google_credentials)
  category     = "env"
  workspace_id = tfe_workspace.gcp_project[each.value].id
  description  = "GCP Service Account used to manage GCP resources"
  sensitive    = true
}

variable "google_credentials" {
  description = "value"
  type        = string
}
