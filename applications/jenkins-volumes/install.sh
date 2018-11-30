#!/bin/bash

#
# Mount the NFS share and make directories for all the jenkins volumes
#
kubectl delete pod prepare-volumes || echo "nevermind"
kubectl apply -f prepare-volumes.yaml


#
# Create Jenkins PVC and PV volumes
#
kubectl apply -f nfs-jenkins-home-pv.yaml
kubectl apply -f nfs-jenkins-shared-pv.yaml