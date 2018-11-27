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

source $DIR/files/common
source $DIR/out/common # Use the AWS testbed, override cluster spec in files/common with out/common 

uploadFiles $MASTER_NODE_HOSTNAME

# 
# Run kubeadm init on the master node. This command will:
#
#   Create a fresh kubernetes master node
#   Configure the join token to never expire
#   Configure the kube pod network subnet and service subnet to be exclusive of the
#     corporate network subnet.
#   Save the output into kubeadm-init.log so we later can reference the join token.
#   Edit kubelet configuration to have a compatible kube dns service IP address,
#     (This is probably a bug in kubeadm)
#   Set up the admin user with the kubeconfig in the right places
#  
ssh $SSH_OPTS admin@$MASTER_NODE_HOSTNAME bash -x <<EOF 
rm -rf kubeadm-init.log
sudo kubeadm init \
    --ignore-preflight-errors cri \
    --token-ttl 0 \
    --pod-network-cidr=${POD_NETWORK_CIDR} \
    --apiserver-cert-extra-sans=${MASTER_NODE_HOSTNAME} \
    --service-cidr=${SERVICE_NETWORK_CIDR} | tee kubeadm-init.log


sudo cp /etc/kubernetes/admin.conf \$HOME
sudo chown admin \$HOME/admin.conf
mkdir -p \$HOME/.kube 
cp \$HOME/admin.conf \$HOME/.kube/config
EOF

localKubeconfig