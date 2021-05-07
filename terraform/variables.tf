################################################################################
#
# bootstrap
#   A Terraform project to provision the resources needed to deploy the project.
#
# variables.tf
#   Defines the terraform variables for the project.
#
################################################################################

variable "terraform_cloud_oauth_token_id" {
    description = "The identifier of the OAuth Token created in the Workspace (starts with ot-)"
    default     = "ot-gU64RbHvGesz6Etk"
    type        = string
}