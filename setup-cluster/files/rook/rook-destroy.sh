#!/bin/bash

kubectl delete -f rook-config.yaml
kubectl delete -f rook-single-storageclass.yaml
kubectl delete -f rook-storageclass.yaml
kubectl -n rook delete pod rook-tools
kubectl -n rook delete ds rook-agent
kubectl -n rook delete rs rook-ceph-mon0 rook-ceph-mon1 rook-ceph-mon2
kubectl -n rook delete deployment rook-ceph-mgr0 rook-ceph-mgr1
kubectl -n rook delete deployment rook-api
kubectl delete clusterrolebinding rook-agent-view-all
kubectl delete clusterrolebinding rook-agent-view-all
kubectl delete crd {filesystems.rook.io,objectstores.rook.io,pools.rook.io,volumeattachments.rook.io}

CRD=`kubectl get crd | grep cluster | cut -d" " -f1` && kubectl patch crd $CRD -p '{"metadata":{"finalizers": [null]}}'
kubectl delete crd clusters.rook.io

kubectl -n rook delete po,svc --all --force --grace-period=0
kubectl -n rook delete pod --all --force --grace-period=0
kubectl -n rook-system delete po,svc --all --force --grace-period=0
kubectl -n rook-system delete pod --all --force --grace-period=0


kubectl delete namespace rook
kubectl delete namespace rook-system


kubectl get pods --all-namespaces | grep rook

kubectl get crd && kubectl get ns


for nodeHostname in $(kubectl get nodes --output=jsonpath="{..name}") ; do
    ssh $SSH_OPTS  admin@${nodeHostname}.yrdci.rot.hybris.com sudo rm -rf /var-alt/lib/rook /var/lib/rook /rook/storage-dir
done


kubectl get pods --all-namespaces | grep rook



