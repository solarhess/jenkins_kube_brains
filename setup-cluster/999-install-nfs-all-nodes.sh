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
nohup apt-get install -y nfs-common & 
EOF

}

echo "Prepareing nodes with basic dependencies for the kubernetes cluster"
if [ $# -gt 0 ]; then
    for node_hostname in $@ ; do 
        prepareNode $node_hostname;
    done
else
    for node_hostname in $(kubectl get nodes -o 'jsonpath={.items[*].status.addresses[].address}') ; do 
        prepareNode $node_hostname;
    done
fi


