#!/bin/bash

KUBE_NAMESPACE=default

#
# Mount the NFS share and make directories for all the jenkins volumes
#
kubectl -n $KUBE_NAMESPACE delete pod prepare-volumes || echo "nevermind"
kubectl -n $KUBE_NAMESPACE apply -f prepare-volumes.yaml


#
# Create Jenkins PVC and PV volumes
#
kubectl -n $KUBE_NAMESPACE apply -f nfs-jenkins-home-pv.yaml
kubectl -n $KUBE_NAMESPACE apply -f nfs-jenkins-shared-pv.yaml