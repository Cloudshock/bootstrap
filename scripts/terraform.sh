#!/bin/bash
################################################################################
#
# scripts / terraform.sh
#   This script is a wrapper for the Terraform CLI.  If Terraform is not
#   installed, or if an imcompatible version of Terraform is present, this
#   script uses a Docker container to run the correct version of Terraform.
#
#   Usage:
#       ./scripts/terraform.sh [<command> [<argument>...]]
#
#   Where:
#       <command>   Is the Terraform command to execute
#       <argument>  Are the arguments passed to the Terraform command
#
#   If no command is specified, the script will mimick the behaviour of running
#   the Terraform CLI with no command, which is to run the terraform help
#   command.
#   For any other command, the script will execute a terraform init command
#   first, prior to executing the specified command, unless that command is
#   init.  In this case the script will only run terraform init once with any
#   provided arguments. 
#
################################################################################
set -eu${DEBUG:+x}o pipefail

base_directory="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null ; pwd -P)"

source "$base_directory/functions.sh"

cd "$base_directory/../terraform"

if [[ $# == 0 ]]; then
    command=help
else
    command=${1}
    shift
fi

case $command in
help)
    terraform help "$@"
    ;;
init)
    terraform init "$@"
    ;;
*)
    terraform init
    terraform $command "$@"
    ;;
esac
