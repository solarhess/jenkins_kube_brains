#!/bin/bash

#
# Usage: create-docker-secrets (namespace)
# Calls the AWS api to get the docker secrets. then applies those
# secrets to the kubernetes registry.
#

KUBE_NAMESPACE=${1:-default}

set -eio pipefail
set -x

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR


#
# Call aws through the command line and get the credentials for your Amazon ECR registry
# 
# docker login -u AWS -p theReallyLongPassword -e none https://yourregistryurl.amazonaws.com
#
DOCKER_LOGIN_COMMAND=$(aws --profile=yaas_stout_prod ecr get-login --region us-east-1)

registry_user=$(perl -n -e '/-u (\S+)/ && print $1' <<< "$DOCKER_LOGIN_COMMAND")
registry_password=$(perl -n -e '/-p (\S+)/ && print $1' <<< "$DOCKER_LOGIN_COMMAND")
registry_server=$(perl -n -e '/ (https\:\/\/.*)$/ && print $1' <<< "$DOCKER_LOGIN_COMMAND")

#
# Put a new docker registry secret in your kubernetes namespace
#
kubectl -n $KUBE_NAMESPACE create secret docker-registry ecr-registry-secret \
  "--docker-server=$registry_server" \
  "--docker-username=$registry_user" \
  "--docker-email=$registry_user" \
  "--docker-password=$registry_password"

#
# Patch the default service account in your namespace to automatically use
# the docker registry a new docker registry secret in your kubernetes namespace.
# This way we don't have to specify imagePullSecrets on every pod template
#
kubectl -n $KUBE_NAMESPACE patch serviceaccount default -p '{"imagePullSecrets": [{"name": "ecr-registry-secret"}]}'
set +x
cat <<EOF

You may now push images to $registry_server 
running on AWS Elastic Container Registry. 

EOF