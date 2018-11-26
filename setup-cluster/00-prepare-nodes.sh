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
    echo "Preparing node. Please enter admin password to set up nopasswd sudo"
    echo "If  don't have sudoers access. please run this command"
    echo "   ssh admin@${node_hostname}"
    echo '    echo "admin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/admin'

    uploadFiles ${node_hostname}
    ssh "admin@${node_hostname}" sudo bash -x /home/admin/files/prepare-node.sh || echo "Unable to connect to ${node_hostname}"
}

echo "Prepareing nodes with basic dependencies for the kubernetes cluster"
if [ $# -gt 0 ]; then
    for node_hostname in $@ ; do 
        prepareNode $node_hostname;
    done
else
    prepareNode $MASTER_NODE_HOSTNAME
    for node_hostname in  ${WORKER_NODES_HOSTNAMES[*]}  ; do 
        prepareNode $node_hostname;
    done
fi


