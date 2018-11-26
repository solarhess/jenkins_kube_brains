#!/bin/bash

# set -x

#
# This script scans all the worker nodes and checks if they have
# kubelet installed and have joined the cluster. This then runs
# the necessary 
#
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

echo "*"
echo "*"
echo "* Attempting SSH to all nodes to ensure the host key is installed on this client"
echo "*"
echo "*"
echo 
for worker_hostname in ${WORKER_NODES_HOSTNAMES[*]} ; do 
    ssh admin@${worker_hostname} hostname
done

echo 
echo "*"
echo "*"
echo "* Checking all hosts for necessary software installed"
echo "*"
echo "*"
echo 
for worker_hostname in ${WORKER_NODES_HOSTNAMES[*]} ; do 
    echo
    echo "*"
    echo "*"
    echo "* Preparing worker node $worker_hostname"
    echo "*"
    echo "*"
    echo 

    ssh admin@${worker_hostname} > worker-check.out <<EOF
echo HOSTNAME `hostname`
sudo echo "NOPASSWD SUDOERS OK"
dpkg -s kubelet && echo "KUBELET INSTALLED OK" || echo "NO KUBELET INSTALLED"
systemctl status kubelet | grep running && echo "KUBELET RUNNING OK" || echo "NO RUNNING KUBELET"
EOF

    worker_local_hostname=$(grep 'HOSTNAME' worker-check.out | cut -c8 )
    if grep -q "NOPASSWD SUDOERS OK" worker-check.out ; then 
        echo "Adding worker: $worker_hostname aka $worker_local_hostname" 
        if grep -qF "KUBELET INSTALLED OK" worker-check.out ; then
            echo "Kubelet installed. Skipping prepare nodes step"
        else
            echo "preparing node ${worker_hostname}"
            ./00-prepare-nodes.sh $worker_hostname
        fi
        if  grep -qF "KUBELET RUNNING OK" worker-check.out ; then 
            echo "Kubelet running ok. Skipping add worker step"
        else
            echo "adding node to cluster"
            ./30-add-worker.sh $worker_hostname
            ./999-reboot-all-nodes.sh $worker_hostname
        fi
    else 
        echo "$worker_hostname cannot sudo without a passsword" 
    fi
done