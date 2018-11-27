#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR


source ./files/common
source ./out/common

function prepareNode() {
    local node_hostname=$1
    set +e
    
    ssh $SSH_OPTS  "admin@${node_hostname}" sudo bash -x <<EOF
kubeadm reset -f
rm -rf /var-alt/lib/rook
rm -rf /var/lib/kubelet
rm -rf /var-alt/lib/kubelet
rm -rf /var/lib/etcd
rm -rf /etc/kubernetes

mkdir -p /var-alt/lib/kubelet
ln -s /var-alt/lib/kubelet /var/lib/kubelet

shutdown -r now
EOF


}

echo "Destroying the cluster. All will be lost. Press return to continue. ctrl-c to cancel"
read OK

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


