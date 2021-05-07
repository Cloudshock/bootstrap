#!/bin/bash
################################################################################
#
# scripts / initial-setup.sh
#   This script creates the resources needed as part of the initial setup.  This
#   script is interactive and will require inputs from the operator.
#
#   Refer to the Initial Setup section in the README.md file.
#
################################################################################
set -eu${DEBUG:+x}o pipefail

base_directory="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null ; pwd -P)"

source "$base_directory/functions.sh"

# Authenticate the operator
gcloud auth login

# Enter main loop
while true; do
    read -p "Enter 6 digit sequence for Project ID suffix: " suffix

    if echo "$suffix" | grep -qE '[0-9]{6}' ; then
        break
    fi

    echo "Invalid sequence"
done

while true; do
    echo "Existing Google Cloud billing accounts"
    gcloud beta billing accounts list

    read -p "Select one of the billing accounts by entering the ACCOUNT_ID: " billing_account

    # Make there's a valid value
    if [[ $(gcloud beta billing accounts list --filter "name = billingAccounts/$billing_account" --format "get(name)" | wc -l | awk '{print $1}') == 1 ]] ; then
        break
    fi

    echo "The provided ACCOUNT_ID is not valid."
done

gcloud projects create cloudshock-$suffix --name CLOUDSHOCK --labels="creation-repository=bootstrap,persistent=true,created-by=$(whoami)"
gcloud projects create cloudshock-dev-$suffix --name CLOUDSHOCK-DEV --labels="creation-repository=bootstrap,persistent=true,created-by=$(whoami)"

gcloud beta billing projects link cloudshock-$suffix --billing-account="billingAccounts/$billing_account"
gcloud beta billing projects link cloudshock-dev-$suffix --billing-account="billingAccounts/$billing_account"

gcloud projects list --filter "cloudshock-"

# Create a single Service Account in the restricted project
gcloud iam service-accounts create tc-bootstrap --description "Service Account used by Terraform Cloud to run bootstrap project" --project cloudshock-$suffix > /dev/null

# Give the single Service Account the Owner role in both projects
gcloud projects add-iam-policy-binding cloudshock-$suffix --member=serviceAccount:tc-bootstrap@cloudshock-$suffix.iam.gserviceaccount.com --role=roles/owner > /dev/null
gcloud projects add-iam-policy-binding cloudshock-dev-$suffix --member=serviceAccount:tc-bootstrap@cloudshock-$suffix.iam.gserviceaccount.com --role=roles/owner > /dev/null

# Create a Key for the Service Account
gcloud iam service-accounts keys create ./gcp-credentials.json --iam-account=tc-bootstrap@cloudshock-$suffix.iam.gserviceaccount.com > /dev/null

terraform login

# Retrieve the email address from the Terraform Cloud account details
email_address="$(curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    https://app.terraform.io/api/v2/account/details | \
        jq -r '.data.attributes.email')"

# Create the Terraform Cloud Organization
curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"organizations","attributes":{"name":"cloudshock","email":"'$email_address'","collaborator-auth-policy":"two_factor_mandatory"}}}' \
    https://app.terraform.io/api/v2/organizations > /dev/null

# Create the Terraform Cloud Organization API Token
organization_token="$(curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    https://app.terraform.io/api/v2/organizations/cloudshock/authentication-token | \
        jq -r '.data.attributes.token')"

# Create the bootstrap Terraform Cloud Workspace
workspace_id="$(curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"workspaces","attributes":{"name":"bootstrap","allow-destroy-plan":false,"description":"Bootstraps Terraform Cloud and GCP resources","terraform-version":"0.15.1"}}}' \
    https://app.terraform.io/api/v2/organizations/cloudshock/workspaces | \
        jq -r '.data.id')"

# Create the TFE_TOKEN Terraform Cloud Workspace Variable
curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"vars","attributes":{"key":"TFE_TOKEN","value":"'$organization_token'","description":"Terraform Cloud Organization API Token used to configure Workspaces","category":"env","sensitive":true}}}' \
    https://app.terraform.io/api/v2/workspaces/$workspace_id/vars > /dev/null

# Create the GOOGLE_CREDENTIALS Terraform Cloud Workspace Variable
curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"vars","attributes":{"key":"GOOGLE_CREDENTIALS","value":"'$(cat "./gcp-credentials.json" | tr -d '\n')'","description":"GCP Service Account used to manage GCP resources","category":"env","sensitive":true}}}' \
    https://app.terraform.io/api/v2/workspaces/$workspace_id/vars > /dev/null

# Remove the Service Account Key from the local filesystem now that it has been
# used to create the Terraform Cloud Workspace Variable.
rm -f "./gcp-credentials.json" > /dev/null || true

# Import the bootstrap Terraform Cloud Workspace resource into the Terraform
# State to avoid Terraform trying to create a second Workspace with the same
# name.
cd $base_directory/../terraform/
terraform init > /dev/null
TFE_TOKEN="$(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" terraform import tfe_workspace.bootstrap "$workspace_id" > /dev/null
terraform plan -target=tfe_workspace.bootstrap -detailed-exitcode > /dev/null
