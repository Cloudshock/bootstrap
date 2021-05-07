################################################################################
#
# scripts / functions.sh
#   This file defines bash functions used in the other scripts in this
#   directory.
#
#   This file is not executable.
#
################################################################################

#
# gcloud:
#   Runs a Docker container with the Google Cloud SDK Docker Image to execute a
#   given gcloud command.
#
function gcloud {
    docker run --rm -it -v $temp_directory:/data -v $HOME/.config/gcloud:/root/.config/gcloud -w /root \
        gcr.io/google.com/cloudsdktool/cloud-sdk:slim gcloud "$@"
}

#
# terraform:
#   Runs a Docker container with the Terraform Docker Image to execute a given
#   terraform command.
#
function terraform {
    # If the TFE_TOKEN or GOOGLE_CREDENTIALS environment variables exist,
    # they will be set in the container, otherwise they are omitted.
    docker run --rm -it \
        -e TFE_TOKEN -e GOOGLE_CREDENTIALS \
        -v "$HOME/.terraform.d:/root/.terraform.d" \
        -v "$(pwd -P):/work" \
        -w /work \
        hashicorp/terraform:0.15.1 \
        "$@"
}
