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
source ./out/common

function prepareNode() {
    local node_hostname=$1

    ssh $SSH_OPTS  "admin@${node_hostname}" sudo bash <<EOF
#
# Run this on every node
#

echo "Running on \$(hostname) OK"
sudo modprobe -- ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh
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


