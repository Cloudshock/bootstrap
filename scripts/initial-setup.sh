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

temp_directory=$(mktemp -d "$base_directory/tmpXXXXXX")
trap "rm -rf $temp_directory" EXIT

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


if [[ ${CLOUDSHOCK_TEST:+x} == x ]]; then
    TC_ORGANIZATION=cloudshock-$suffix
fi

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
gcloud iam service-accounts create tc-bootstrap --description "Service Account used by Terraform Cloud to run bootstrap project" --project cloudshock-$suffix

# Give the single Service Account the Owner role in both projects
gcloud projects add-iam-policy-binding cloudshock-$suffix --member=serviceAccount:tc-bootstrap@cloudshock-$suffix.iam.gserviceaccount.com --role=roles/owner
gcloud projects add-iam-policy-binding cloudshock-dev-$suffix --member=serviceAccount:tc-bootstrap@cloudshock-$suffix.iam.gserviceaccount.com --role=roles/owner

# Create a Key for the Service Account
gcloud iam service-accounts keys create /data/gcp-credentials.json --iam-account=tc-bootstrap@cloudshock-$suffix.iam.gserviceaccount.com

terraform login

# Retrieve the email address from the Terraform Cloud account details
email_address="$(curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    https://app.terraform.io/api/v2/account/details | \
        jq -r '.data.attributes.email')"

echo "Retrieved email address '$email_address' from Terraform Cloud"

# Create the Terraform Cloud Organization
TC_ORGANIZATION=${TC_ORGANIZATION:-cloudshock}
curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"organizations","attributes":{"name":"'"$TC_ORGANIZATION"'","email":"'$email_address'","collaborator-auth-policy":"two_factor_mandatory"}}}' \
    https://app.terraform.io/api/v2/organizations

# Create the Terraform Cloud Organization API Token
organization_token="$(curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    https://app.terraform.io/api/v2/organizations/$TC_ORGANIZATION/authentication-token | \
        jq -r '.data.attributes.token')"

if [[ ${#organization_token} != 0 ]]; then
    echo "Organization API Token created in Terraform Cloud"
fi

# Create the bootstrap Terraform Cloud Workspace
workspace_id="$(curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"workspaces","attributes":{"name":"bootstrap","allow-destroy-plan":false,"description":"Bootstraps Terraform Cloud and GCP resources","terraform-version":"0.15.1"}}}' \
    https://app.terraform.io/api/v2/organizations/$TC_ORGANIZATION/workspaces | \
        jq -r '.data.id')"

echo "Workspace '$workspace_id' created in Terraform Cloud"

# Create the TFE_TOKEN Terraform Cloud Workspace Variable
curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"vars","attributes":{"key":"TFE_TOKEN","value":"'$organization_token'","description":"Terraform Cloud Organization API Token used to configure Workspaces","category":"env","sensitive":true}}}' \
    https://app.terraform.io/api/v2/workspaces/$workspace_id/vars

# Create the GOOGLE_CREDENTIALS Terraform Cloud Workspace Variable
curl -sfL \
    -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
    -H "Content-Type: application/vnd.api+json" \
    -X POST \
    -d '{"data":{"type":"vars","attributes":{"key":"GOOGLE_CREDENTIALS","value":"'"$(cat "$temp_directory/gcp-credentials.json" | tr -d '\n' | sed -e 's~"~\\"~g' -e 's~\\n~\\\\n~g')"'","description":"GCP Service Account used to manage GCP resources","category":"env","sensitive":true}}}' \
    https://app.terraform.io/api/v2/workspaces/$workspace_id/vars

# Remove the Service Account Key from the local filesystem now that it has been
# used to create the Terraform Cloud Workspace Variable.
rm -f "$temp_directory/gcp-credentials.json" || true

# Only import the created Workspace into the Terraform State, if using the main cloudshock Terraform Cloud Organization.
if [[ ${CLOUDSHOCK_TEST:+x} == x ]] ; then
    # Pause here to give the operator time to verify that everything was correctly setup.
    echo "Initial Terraform Cloud and GCP resources created."
    read -p "Press ENTER to proceed to destruction phase"

    curl -sfL \
        -H "Authorization: Bearer $(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" \
        -H "Content-Type: application/vnd.api+json" \
        -X DELETE \
        https://app.terraform.io/api/v2/organizations/$TC_ORGANIZATION

    gcloud projects delete cloudshock-dev-$suffix
    gcloud projects delete cloudshock-$suffix

    exit 0
else
    # Import the bootstrap Terraform Cloud Workspace resource into the Terraform
    # State to avoid Terraform trying to create a second Workspace with the same
    # name.
    cd $base_directory/../terraform/
    terraform init
    TFE_TOKEN="$(jq -r '.credentials."app.terraform.io".token' ~/.terraform.d/credentials.tfrc.json)" terraform import tfe_workspace.bootstrap "$workspace_id"
fi
