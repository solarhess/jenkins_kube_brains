#!/bin/bash
set -eio pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR


source ./files/common
localKubeconfig

ssh admin@$MASTER_NODE_HOSTNAME bash <<EOF
    curl -O https://storage.googleapis.com/kubernetes-helm/helm-v2.7.2-linux-amd64.tar.gz
    tar -zxf helm-v2.7.2-linux-amd64.tar.gz
    sudo cp linux-amd64/helm /usr/local/bin
    helm init --upgrade

    kubectl -n kube-system create sa tiller
    kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
    kubectl -n kube-system patch deploy/tiller-deploy -p '{"spec": {"template": {"spec": {"serviceAccountName": "tiller"}}}}'
EOF

# or locally on your mac
# brew install kubernetes-helm || brew upgrade kubernetes-helm
# brew install kubernetes-cli ||  brew upgrade kubernetes-cli
# helm init