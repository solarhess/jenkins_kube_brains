# jenkins + kube = b-r-a-i-n-s
Example scripts to run Kubernetes on your private VMs. This is to support of Loren and my KubeCon 2018 talk "Migrating Jenkins to Kubernetes broke our brains." https://sched.co/GrSh

More details to follow

## Planning

TODO List for documentation

* DONE Scrub private data
* DONE document the shell scripts as-is
* DONE Get it working on AWS VMs
  * Spin up 4 Debian VMs
  * Run scripts to set up system
  * Set up with Azure or AWS DNS
* Update to current practices
  * Monitoring with helm + prometheus + grafana https://akomljen.com/get-kubernetes-cluster-metrics-with-prometheus-in-5-minutes/
  * DONE kubecertmanager for certificates
* Write documentation on kube setup into this repo
  * Conditions of our environment that resulted in this approach
  * External servcies setup
  * Kubernetes setup
* Demonstrate the NFS server & pinned node
* Links to helpful Kube tools - kubespy, stern
* Add Jenkins Stuff

## Cluster Setup

You go through several steps to get the cluster up and running. To get started,
open your terminal and CD to the setup-cluster directory. Run these scripts
in sequence starting with `00-create-aws-testbed.sh` and ending with `05-nginx-ingress.sh`

### Step 00 with AWS: 00-create-aws-testbed.sh (optional)

Assuming you have an AWS account all ready to go, this step will get 4 Debian 9 VMs up and running
on a VPC with networking similar to what you might get on a corporate network. This will write all
your configuration information into out/common in order to run the rest of these scripts.

### Step 00 alternate: edit files/common

If you are running this against your own datacenter you will need to manually spin up
some VMs running Debian 9. Then, you will need to edit [setup-cluster/files/common](setup-cluster/files/common) to
include information about your VMs.

### Step 01: 01-prepare-nodes.sh

This installs all of the dependencies you are going to need in order to run kubeadm and
set up your cluster. Take a look at [setup-cluster/files/prepare-node.sh](setup-cluster/files/prepare-node.sh) for details
on what this actually does to your cluster.

### Step 10: 20-configure-cluster.sh

This installs the Weave pod networking for your kubernetes cluster.
See [setup-cluster/20-configure-cluster.sh](setup-cluster/20-configure-cluster.sh)

### Step 30: 30-add-worker.sh

This connects to the workers and joins them to the cluster one by one. If you call
this with the hostname of a worker node as an argument, it will join just the worker node. If you 
call this with no arguments, it will join all the worker nodes listed in files/common
See [setup-cluster/30-add-worker.sh](setup-cluster/30-add-worker.sh)

### Step 40: 40-install-helm.sh

This goes through a few steps on the master node to install helm. See [setup-cluster/40-install-helm.sh](setup-cluster/40-install-helm.sh)

### Step 50: 50-nginx-ingress.sh

This will set up your nginx ingress controller, along with cert-manager which will
automatically issue SSL certificates via LetsEncrypt, assuming this cluster is
addressable via a public DNS address. [setup-cluster/50-nginx-ingress.sh](setup-cluster/50-nginx-ingress.sh)

### Final Step: Manually configure DNS

Once you have gotten through step 50-nginx-ingress, you will need to manually set up
a DNS record to point to the node running the ingress.

For example, I created two DNS records like this through my DNS service:

    A kubecon2018.jonathanhess.com  54.89.184.57
    A *.kubecon2018.jonathanhess.com  54.89.184.57

Now I can create ingresses in my kubernetes cluster for FQDNs like
grafana.kubecon2018.jonathanhess.com or jenkins.kubecon2018.jonathanhess.com.
When I do, the external http clients and web browsers will look up this public DNS
record, get referred to my ingress node via the '*.kubecon2018.jonathanhess.com' record.
Then, the ingress controller will recognize the inbound hostname, serve
the correct certificate, and forward traffic to the correct kubernetes service.

## Running Everything

Now we walk you through running Jenkins on your kubernetes environment.
To run these scripts, the basic assumptions are:

* The kubectl on your local machine is set up to connect to your cluster. You may want to set the KUBECONFIG environment variable.
* You have an existing private git repository.
* You have an existing private docker registry where you can push and pull images.

### Hello World

We have provided a hello-world example for you to make sure that your cluster is actually working.  You will first need to dit [applications/helloworld/helloworld.yaml](applications/helloworld/helloworld.yaml) to replace my domain `.kubecon2018.jonathanhess.com` with the domain that you set up in the final
step of spinning up the cluster.

Once that is done, simply run  `kubectl apply -f applications/helloworld/helloworld.yaml` to deploy your helloworld application.
use `kubectl get pods` to ensure that your pod starts up.

Then, point your browser at https://helloworld.[your domain here]/. You should
see a "untrusted certificate warning" and then eventually a page with the title "Hello World Jenkins Brains."

To simplify helloworld, we put all the kubernetes definitions in the same
yaml file. We found that this is bad practice for any application larger than
hello world.

### Docker Registry Secrets

We found it conveninent to configure kubernetes to automatically check
the docker registry secrets for your private repository. To do this you
will create a new docker-registry secret in your kubernetes cluster. Then
you will patch the service account to automatically try that secret when pulling images.

The example script [applications/create-docker-secrets.sh](applications/create-docker-secrets.sh) demonstrates how to use the `kubectl` commands to set up the secrets.

### Run an NFS Server for persistant volumes

Jenkins needs a home. In particular, it needs a persistent directory called "JENKINS_HOME" that lasts longer than any pod running Jenkins to store secrets,configuration, etc. When you spin up your own kubernetes cluster, kubernetes doesn't include easy persistent volume support. So we developed the technique
of pinning an NFS server to a particular node, and serve the nfs shared volume
from that node's local disk. 

First, edit [applications/nfs/nfs-server-rc.yaml](applications/nfs/nfs-server-rc.yaml) to remove the settings for my cluster and replace them with settings for your cluster. 

* Replace the node hostname `ip-10-0-129-205` with the hostname of a node in your cluster.
* Replace the host path `/var-alt/lib/jenkins-nfs` with the host path appropriate for your setup.

Then, edit [applications/nfs/nfs-server-service.yaml](applications/nfs/nfs-server-service.yaml) to remove the settings for my cluster and replace them with settings for your cluster.

* Change the ClusterIP address, picking a valid address in your cluster's 
  service subnet [See SERVICE_NETWORK_CIDR=192.168.128.0/17 in common](setup-cluster/files/common)

Then create the server and service for kubernetes:  `kubectl apply -f nfs-server-rc.yaml`  and `kubectl apply -f nfs-server-service.yaml` 

Now you have an NFS server running in your cluster. Note the service address,
you will need it later.

### Declare persistent volumes for Jenkins

You need 2 persistent volumes for jenkins to be created before you start: a volume for Jenkins Home to be mounted on the Jenkins master, and a volume for Jenkins Shared Folders to be mounted by all the jenkins slaves. Because you 
are rolling your own persistent storage with NFS, you need to allocate these
volumes yourself.

Edit `applications/jenkins-volumes/nfs-jenkins*-pv.yaml` and put in the IP address from [applications/nfs/nfs-server-service.yaml](applications/nfs/nfs-server-service.yaml). 

Run `applications/jenkins-volumes/install.sh` to get the volumes created.
This will create the persistent volumes and also mount the NFS server to create
the directories to hold the data for those volumes.

Run `kubectl get pv` to confirm that the volumes get created and end up in state 'Bound'

Now you will be able to reference the persistent volume claims in your Jenkins
helm chart: 

    * jenkins-home-pvc - the home directory for Jenkins
    * jenkins-shared-pvc - a shared folder to pass files between slaves

### Launch the Jenkins helm chart

Go to applications/jenkins
Edit jenkins-values.yaml
* change 'jenkins.kubecon2018.jonathanhess.com' to your hostname in 2 places

Run jenkinsctl.sh install to install everything

Update your git repos... put the application/jenkins/out/id_rsa.pub as an access key


### Smoke test to make sure it is working

Make sure Jenkins is talking to K8s... go to "Manage Jenkins/Configuration" Scroll down the section called "Cloud/Kubernetes" click the "Test Connection" button. It should work

Create a "freestyle job" with a single "execute shell script" in it. Run the build to make sure that it runs. 

Yay! You did it!


### Customize your Jenkins master docker image

### Customize your Jenkins worker docker image

### Passing large files

## Useful Tips and Tools 

Here are some tips that we have evolved:

* Set your bash alias kc=kubectl to save yourself some typing
* When working with lots of clusters, use the KUBECONFIG environment variable. 
  Make sure you always set the absolute path to the kubeconfig file.

Here are some useful command line tools to help you with Kubernetes

* stern - follows aggregates logs from pods of the same deployment
* kubespy - command line to watch the status of deployments

