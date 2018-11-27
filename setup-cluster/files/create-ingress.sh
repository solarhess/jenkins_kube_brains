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
# Install the secret for ${SERVICE_NAME}
# Note, this is the wrong way to generate certificates. There are beter alternatives now.
# If you are on the public internet with a real DNS name, use letsencrypt instead
# 
if ! kubectl -n $KUBE_NAMESPACE get secrets ${SERVICE_NAME}-ingress-secret ; then 
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt -subj "/CN=${INGRESS_HOSTNAME}.maurice.ecp.ydev.hybris.com" || die "couldn't create key"
    kubectl -n $KUBE_NAMESPACE  create secret tls ${SERVICE_NAME}-ingress-secret --key /tmp/tls.key --cert /tmp/tls.crt || die "couldn't install secret"
fi
rm /tmp/tls.key /tmp/tls.crt

#
# 
#
if ! kubectl -n $KUBE_NAMESPACE get ingress ${SERVICE_NAME}-ingress ; then 
cat > /tmp/${SERVICE_NAME}-ingress.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ${SERVICE_NAME}-ingress
  namespace: ${KUBE_NAMESPACE}
spec:
  tls:
  - hosts:
    - ${INGRESS_HOSTNAME}.maurice.ecp.ydev.hybris.com
    secretName: ${SERVICE_NAME}-ingress-secret 
  rules:
  - host: ${INGRESS_HOSTNAME}.maurice.ecp.ydev.hybris.com
    http:
      paths:
      - backend:
          serviceName: ${SERVICE_NAME}
          servicePort: ${SERVICE_PORT}
        path: /
EOF
    kubectl apply -f /tmp/${SERVICE_NAME}-ingress.yaml
fi

