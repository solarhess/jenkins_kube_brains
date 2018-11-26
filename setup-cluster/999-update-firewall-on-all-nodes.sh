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

function prepareNode() {
    local node_hostname=$1
    uploadFiles ${node_hostname}
    ssh "admin@${node_hostname}" sudo bash -x <<EOF
systemctl disable ferm.service
systemctl stop ferm.service
reboot
EOF

}

echo "Prepareing nodes with basic dependencies for the kubernetes cluster"
if [ $# -gt 0 ]; then
    for node_hostname in $@ ; do 
        prepareNode $node_hostname;
    done
else
    for node_hostname in ${WORKER_NODES_HOSTNAMES[*]} ; do 
        prepareNode $node_hostname;
    done
    prepareNode $MASTER_NODE_HOSTNAME
fi

# Now reset all k8s
KUBE_PROXY_PODS="$(kubectl -n kube-system get pods -l 'k8s-app=kube-proxy' -o 'jsonpath={..metadata.name}')"
kubectl -n kube-system delete pod ${KUBE_PROXY_PODS}
