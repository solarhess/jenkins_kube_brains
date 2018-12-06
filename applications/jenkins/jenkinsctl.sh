#!/bin/bash
set -eio pipefail
set -x

KUBE_NAMESPACE=default

# A folder for generated files that won't go into git.

mkdir -p out 

function install() {

    #
    # Generate the SSH Key if necessary and also create
    # a secret on 
    #
    if [[ ! -f out/id_rsa ]] ; then 
        ssh-keygen -N "" -f out/id_rsa
    fi
    set +x
    
    key=$(base64 out/id_rsa)
    keypub=$(base64 out/id_rsa.pub)

    cat > out/ssh-secrets.yaml <<EOF
kind: Secret
apiVersion: v1
metadata:
  namespace: $KUBE_NAMESPACE 
  name: jenkins-user-ssh-secrets
data:
  id_rsa: ${key}
  id_rsa.pub: ${keypub}
EOF
    set -x
    kubectl -n $KUBE_NAMESPACE apply -f out/ssh-secrets.yaml
    helm install --name jenkins -f jenkins-values.yaml stable/jenkins --namespace $KUBE_NAMESPACE || die "Did not deploy"
}

function help() {
    set +x
    cat <<EOF

jenkinsctl.sh <command>

This script gets Jenkins running in your cluster
Here are some helpful commands to keep running:

    ./jenkinsctl.sh install        # Run the helm chart to install Jenkins
    ./jenkinsctl.sh status         # Show the helm status of your jenkins cluster 
    ./jenkinsctl.sh printPassword  # Prints out the password to log into jenkins
    ./jenkinsctl.sh upgrade        # Helm upgradeds your jenkins
    ./jenkinsctl.sh deleteWorkers  # Delete all the jenkins worker pods
    ./jenkinsctl.sh destroy        # Delete Jenkins from your cluster

Jenkins now has its own SSH key to access your git repos. 
You can find this key in $PWD/out/id_rsa.pub
Or copy from here: 

EOF
cat $PWD/out/id_rsa.pub
cat <<EOF

Copy this as an access key into your cluster.
Happy Building!

EOF

}

function upgrade() {
    helm upgrade jenkins -f jenkins-values.yaml stable/jenkins --namespace $KUBE_NAMESPACE
}

function destroy() {
    if helm status jenkins ; then
        helm delete --purge jenkins
        sleep 120
    fi
    deleteWorkers
}

function status() {
    helm status jenkins
}

function printPassword() {
    set +x
    echo
    echo "The jenkins credentials are: "
    echo "  Username: admin"
    printf "  Password: %s\n" $(kubectl get secret --namespace default jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode)
    echo 
}

function resetMaster() {
    kubectl -n $KUBE_NAMESPACE delete pod --selector="component=jenkins-jenkins-master"
    deleteWorkers
}

function deleteWorkers() {
    echo "Deleting all worker jobs"
    #kubectl -n buildops delete pod $(kubectl -n buildops  get pods -a -l 'jenkins=slave' -o "jsonpath={..metadata.name}")
    kubectl -n $KUBE_NAMESPACE -l jenkins=slave delete pods
}

if [[ -z ${1:-} ]] ; then 
    help
fi

$@
