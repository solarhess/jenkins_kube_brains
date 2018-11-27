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
    kubectl apply -f files/kube-dashboard.yaml
    kubectl apply -f files/kube-dashboard-auth.yaml
    kubectl -n kube-system describe secret \$(kubectl -n kube-system get secret | grep admin-user | awk '{print \$1}')
EOF

echo "Print out the access token using this command:"
echo "   kubectl -n kube-system describe secret \$(kubectl -n kube-system get secret | grep admin-user | awk '{print \$1}')"
echo "Then run kube proxy to set up a proxy server to access the dashboard"
echo "   kubectl proxy"    
echo "Finally, direct your browser to: "
echo "   http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/"
