#!/bin/bash

#
# Instructions to install weave networking into the cluster
#
sudo sysctl net.bridge.bridge-nf-call-iptables=1
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever&env.IPALLOC_RANGE=192.168.0.0/17"
