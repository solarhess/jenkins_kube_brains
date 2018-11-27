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
    --service-cidr=${SERVICE_NETWORK_CIDR} | tee kubeadm-init.log

sudo perl -pi -e 's/10.96.0.10/${KUBE_DNS_SERVICE_IP}/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet docker

sudo cp /etc/kubernetes/admin.conf \$HOME
sudo chown admin \$HOME/admin.conf
mkdir -p \$HOME/.kube 
cp \$HOME/admin.conf \$HOME/.kube/config
EOF

