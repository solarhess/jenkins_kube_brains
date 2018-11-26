#!/bin/bash
# set -eio pipefail
set -x

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR

if ! kubectl -n rook-system get pod -l app=rook-operator | grep -q Running ; then 
  kubectl create -f rook-operator.yaml
fi

# for some reason we still need to assign rook operator
if ! kubectl get  clusterrolebinding rook-agent-view-all ; then 
    kubectl create clusterrolebinding rook-agent-view-all --clusterrole=rook-agent --user=system:serviceaccount:rook:rook-agent
    kubectl create clusterrolebinding rook2-agent-view-all --clusterrole=rook-agent --user=system:serviceaccount:rook2:rook-agent
fi

if ! kubectl get  clusterrolebinding rook-system-agent-view-all ; then 
    kubectl create clusterrolebinding rook-system-agent-view-all --clusterrole=rook-agent --user=system:serviceaccount:rook-system:rook-agent
fi

# Wait for the operator to start before running rook configurations
while ! ( kubectl -n rook-system get pod -l app=rook-operator | grep -q Running ) ;  do
  echo "Waiting for the operator to start"
  sleep 10
done

kubectl create -f rook-config.yaml

sleep 30

kubectl create -f rook-single-storageclass.yaml

kubectl create -f rook-storageclass.yaml

kubectl apply -f rook-tools.yaml

sleep 30 

# Update replica pool setings to get this out of warning state
# see https://ekuric.wordpress.com/2016/02/09/increase-number-of-pgpgp-for-ceph-cluster-ceph-error-too-few-pgs-per-osd/
kubectl -n rook exec -it rook-tools ceph osd pool set replicapool pg_num 400
kubectl -n rook exec -it rook-tools ceph osd pool set replicapool pgp_num 400

kubectl -n rook exec -it rook-tools ceph osd pool set replicapool-single pg_num 400
kubectl -n rook exec -it rook-tools ceph osd pool set replicapool-single pgp_num 400

kubectl -n rook exec -it rook-tools rookctl status

# Show rook status
# kubectl apply -f rook-tools.yaml
# kubectl -n rook exec -it rook-tools bash
#    ... rookctl status

