################################################################################
#
# bootstrap
#   A Terraform project to provision the resources needed to deploy the project.
#
# tfe.tf
#   Defines the Terraform Cloud resources.
#
################################################################################

# Configuring the google provider, the credentials attribute is provided by the
# GOOGLE_CREDENTIALS environment variable.
provider "google" {
}

variable "gcp_project_suffix" {
  description = "The common suffix used for all GCP Project IDs."
  type        = string
  default     = "344990"
}

locals {
  gcp_project_ids = [
    "cloudshock-${var.gcp_project_suffix}",
    "cloudshock-dev-${var.gcp_project_suffix}",
  ]
  gcp_services = [
    "compute.googleapis.com",
  ]
}

resource "google_project_service" "cloudshock" {
  for_each = toset(local.gcp_services)

  project = "cloudshock-${var.gcp_project_suffix}"
  service = each.value
}

resource "google_project_service" "cloudshock_dev" {
  for_each = toset(local.gcp_services)

  project = "cloudshock-dev-${var.gcp_project_suffix}"
  service = each.value
}

