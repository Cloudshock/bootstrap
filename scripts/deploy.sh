#!/bin/bash
################################################################################
#
# scripts / deploy.sh
#   This script triggers a Terraform run of the regular configuration.  Whenever
#   the Terraform configuration is modified, this script needs to be launched to
#   apply the changes.
#
################################################################################
set -eu${DEBUG:+x}o pipefail

base_directory="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null ; pwd -P)"

source "$base_directory/functions.sh"

cd "$base_directory/../terraform"
terraform init

terraform apply
