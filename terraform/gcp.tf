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

variable "gcp_projects" {
  description = "The list of GCP Projects (Project ID) to configure."
  type        = set(string)
  default     = ["cloudshock-dev-344990", "cloudshock-344990",]
}

#resource "google_project_service" "cloudshock" {}
