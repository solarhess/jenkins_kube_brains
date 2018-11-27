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
uploadFiles $MASTER_NODE_HOSTNAME

# install ssl certificate kube-system/default-ingress-certificate

# Assign a pod node to be the host
# see https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#step-one-attach-label-to-the-node

# Assign an arbitrary label to our ingress node
# also know as 10.27.165.228/24
# or stout-2.prod.datahub.ecp.ydev.hybris.com

ssh $SSH_OPTS  admin@$MASTER_NODE_HOSTNAME bash <<EOF
    if helm status nginx-ingress ; then 
        helm delete --purge nginx-ingress
    fi
    kubectl label nodes host-p-11251 --overwrite=true nginxingress=true
    helm install --namespace kube-system --name nginx-ingress stable/nginx-ingress -f files/nginx-ingress-values.yaml
EOF