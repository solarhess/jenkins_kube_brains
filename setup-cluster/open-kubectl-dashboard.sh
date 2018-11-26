#!/bin/bash
KUBE_MASTER=stout-1.prod.datahub.ecp.ydev.hybris.com

if ! kubectl get nodes ; then
    echo "Please install kubectl and connect it to the maurice cluster."
    exit 1
fi

KUBE_ADMIN_USER_SECRET_NAME=$(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}' )
DASHBOARD_TOKEN=$(kubectl -n kube-system get secret ${KUBE_ADMIN_USER_SECRET_NAME}  -o jsonpath="{..data.token}" | base64 -D | tr -d '\n' )

echo "${DASHBOARD_TOKEN}" | pbcopy 

# DASHBOARD_TOKEN=`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')`
echo "Please navigate to this URL: "
echo "    http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/" 
echo
echo "This token has been coppied to your clipboard. Use it when prompted to log in."
echo "   $DASHBOARD_TOKEN"
echo 
(sleep 2 ; open http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/) &
echo "Starting kube proxy on 8001"
kubectl proxy
