#!/bin/bash
set -x
set -eio pipefail

KUBE_NAMESPACE=$1
SERVICE_NAME=$2
SERVICE_PORT=$3
INGRESS_HOSTNAME=$4

function die() {
    echo $@
    exit 1
}

#
# Generate bio
#
if ! kubectl -n $KUBE_NAMESPACE get ingress ${SERVICE_NAME}-ingress ; then 
cat > /tmp/${SERVICE_NAME}-ingress.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    # add an annotation indicating the issuer to use.
    certmanager.k8s.io/cluster-issuer: letsencrypt-staging
  name: ${INGRESS_HOSTNAME}
  namespace: ${KUBE_NAMESPACE}
spec:
  rules:
  - host: ${INGRESS_HOSTNAME}.kubecon2018.jonathanhess.com
    http:
      paths:
      - backend:
          serviceName: ${SERVICE_NAME}
          servicePort: ${SERVICE_PORT}
        path: /
  tls: # < placing a host in the TLS config will indicate a cert should be created
  - hosts:
    - ${INGRESS_HOSTNAME}.kubecon2018.jonathanhess.com
    secretName: ${INGRESS_HOSTNAME}-cert # < cert-manager will store the created certificate in this secret.
EOF
    kubectl apply -f /tmp/${SERVICE_NAME}-ingress.yaml
fi

