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

locals {
  gcp_project_ids = [
    "cloudshock-${var.project_suffix}",
    "cloudshock-dev-${var.project_suffix}",
  ]
  gcp_services = [
    "compute.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudkms.googleapis.com",
  ]
}

resource "google_project_service" "cloudshock" {
  for_each = toset(local.gcp_services)

  project = "cloudshock-${var.project_suffix}"
  service = each.value
}

resource "google_project_service" "cloudshock_dev" {
  for_each = toset(local.gcp_services)

  project = "cloudshock-dev-${var.project_suffix}"
  service = each.value
}

data "google_service_account" "tc_bootstrap" {
  account_id = "tc-bootstrap"
  project    = "cloudshock-${var.project_suffix}"
}

resource "google_project_iam_custom_role" "bootstrap" {
  for_each = toset(local.gcp_project_ids)

  role_id     = "terraformCloudBootstrap"
  title       = "Terraform Cloud Bootstrap"
  stage       = "GA"
  project     = each.value
  description = "Custom Role used by Terraform Cloud for the bootstrap Workspace"

  permissions = [
    "cloudkms.keyRings.create",
    "cloudkms.keyRings.get",
    "cloudkms.keyRings.getIamPolicy",
    "cloudkms.keyRings.list",
    "cloudkms.keyRings.setIamPolicy",
    "iam.roles.create",
    "iam.roles.delete",
    "iam.roles.get",
    "iam.roles.list",
    "iam.roles.update",
    "iam.serviceAccounts.get",
    "resourcemanager.projects.getIamPolicy",
    "resourcemanager.projects.setIamPolicy",
    "serviceusage.services.disable",
    "serviceusage.services.enable",
    "serviceusage.services.get",
    "serviceusage.services.list",
  ]
}

resource "google_project_iam_binding" "tc_bootstrap" {
  for_each = toset(local.gcp_project_ids)

  project = each.value
  role    = google_project_iam_custom_role.bootstrap[each.value].name

  members = [
    "serviceAccount:${data.google_service_account.tc_bootstrap.email}",
  ]
}

resource "google_kms_key_ring" "us" {
  for_each = toset(local.gcp_project_ids)

  name     = "unrestricted"
  location = "us"
  project  = each.key
}

resource "google_kms_key_ring" "europe" {
  for_each = toset(local.gcp_project_ids)

  name     = "unrestricted"
  location = "eur4"
  project  = each.key
}

resource "google_kms_key_ring" "australia" {
  for_each = toset(local.gcp_project_ids)

  name     = "unrestricted"
  location = "australia-southeast-1"
  project  = each.key
}

resource "google_kms_key_ring" "asia" {
  for_each = toset(local.gcp_project_ids)

  name     = "unrestricted"
  location = "asia1"
  project  = each.key
}
