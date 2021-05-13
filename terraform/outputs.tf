################################################################################
#
# bootstrap
#   A Terraform project to provision the resources needed to deploy the project.
#
# outputs.tf
#   Defines the output variables for the project.
#
################################################################################

output "project_suffix" {
    description = "The six-digit sequence used as the suffix for all GCP Projects."
    value       = var.project_suffix
}
