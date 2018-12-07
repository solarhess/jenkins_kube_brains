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

set -x
source ./files/common
source ./out/common

localKubeconfig
uploadFiles $MASTER_NODE_HOSTNAME

# One of our constraints is that we can't dyamically change the DNS entry for services
# we host in the cluster. So our quick-and-dirty on premise solution is
# to have a wildcard DNS entry that points at a particular node in our cluster
# Then, we pin the nginx ingress controller to that node in the cluster. 
# 
# Assign a kubernetes label "nginxingress=true" to our ingress node
# see https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#step-one-attach-label-to-the-node
#
# In the helm chart chart values set in files/nginx-ingress-values.yaml, we
# reference the label nginxingress=true to ensure that the nginx ingress controller runs on that node
#
# Now we will manually configure the DNS record to point at the public IP address of this ingress node.
#
# Additionally, we will install cert-manager to magically issue SSL certificates for 
# our ingresses. We will use letsencrypt-staging as our default cluster manager.
# See https://itnext.io/automated-tls-with-cert-manager-and-letsencrypt-for-kubernetes-7daaa5e0cae4

ssh $SSH_OPTS  admin@$MASTER_NODE_HOSTNAME bash <<EOF
    set -x
    if helm status nginx-ingress ; then 
        helm delete --purge nginx-ingress
    fi
    kubectl label nodes $INGRESS_NODE_NAME --overwrite=true nginxingress=true
    helm install --namespace kube-system --name nginx-ingress stable/nginx-ingress -f files/nginx-ingress-values.yaml

    if helm status cert-manager ; then 
        helm delete --purge cert-manager
    fi
    helm install --namespace kube-system --name cert-manager stable/cert-manager \
      --set ingressShim.defaultIssuerName=letsencrypt-staging \
      --set ingressShim.defaultIssuerKind=ClusterIssuer
    kubectl apply -f files/cert-manager-issuer.yaml
EOF

echo "Your ingress will soon be running on $INGRESS_EXTERNAL_IP"
echo "Please create a wildcard DNS entry for $INGRESS_EXTERNAL_IP"
