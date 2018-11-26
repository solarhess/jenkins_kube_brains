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

    ssh "admin@${node_hostname}" sudo bash <<EOF
#
# disable systemd-resolved and resolvconf
# it plays havoc with kubedns
#
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl stop resolvconf.service
systemctl disable resolvconf.service

cat > /etc/resolv.conf <<EOM
nameserver 10.27.224.242
nameserver 10.27.224.243
search prod.datahub.ecp.ydev.hybris.com yrdci.rot.hybris.com
EOM
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


