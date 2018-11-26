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
localKubeconfig
uploadFiles $MASTER_NODE_HOSTNAME

ssh admin@$MASTER_NODE_HOSTNAME bash <<EOF
    kubectl apply -f files/heapster/influxdb.yaml
    kubectl apply -f files/heapster/grafana.yaml
    kubectl apply -f files/heapster/heapster.yaml
    kubectl apply -f files/heapster/heapster-rbac.yaml
    kubectl -n kube-system describe secret \$(kubectl -n kube-system get secret | grep admin-user | awk '{print \$1}')
    files/create-ingress.sh kube-system monitoring-grafana 80 monitoring-grafana
EOF

echo "With kubectl proxy running, you can access grafana here:"
echo "http://localhost:8001/api/v1/namespaces/kube-system/services/monitoring-grafana/proxy/dashboard/db/cluster?orgId=1"

