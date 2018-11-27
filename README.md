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
some VMs running Debian 9. Then, you will need to edit [setup-cluster/files/common] to
include information about your VMs.

### Step 01: 01-prepare-nodes.sh

This installs all of the dependencies you are going to need in order to run kubeadm and
set up your cluster. Take a look at [setup-cluster/files/prepare-node.sh] for details
on what this actually does to your cluster.

### Step 10: 20-configure-cluster.sh

This installs the Weave pod networking for your kubernetes cluster.
See [setup-cluster/20-configure-cluster.sh]

### Step 30: 30-add-worker.sh

This connects to the workers and joins them to the cluster one by one. If you call
this with the hostname of a worker node as an argument, it will join just the worker node. If you 
call this with no arguments, it will join all the worker nodes listed in files/common
See [setup-cluster/30-add-worker.sh]

### Step 40: 40-install-helm.sh

This goes through a few steps on the master node to install helm. See [setup-cluster/40-install-helm.sh]

### Step 50: 50-nginx-ingress.sh

This will set up your nginx ingress controller, along with cert-manager which will
automatically issue SSL certificates via LetsEncrypt, assuming this cluster is
addressable via a public DNS address. [setup-cluster/50-nginx-ingress.sh]

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

