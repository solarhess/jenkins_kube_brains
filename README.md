# jenkins + kube = b-r-a-i-n-s
Example scripts to run Kubernetes on your private VMs. This is to support of Loren and my KubeCon 2018 talk "Migrating Jenkins to Kubernetes broke our brains." https://sched.co/GrSh

More details to follow

## Planning

TODO List for documentation

* DONE Scrub private data
* DONE document the shell scripts as-is
* Get it working on Azure or AWS VMs
  * Spin up 4 Debian VMs
  * Run scripts to set up system
  * Set up with Azure or AWS DNS
* Update to current practices
  * Monitoring with helm + prometheus + grafana https://akomljen.com/get-kubernetes-cluster-metrics-with-prometheus-in-5-minutes/
  * kubecertmanager for certificates
* Write documentation on kube setup into this repo
  * Conditions of our environment that resulted in this approach
  * External servcies setup
  * Kubernetes setup
* Demonstrate the NFS server & pinned node
* Links to helpful Kube tools - kubespy, stern
* Add Jenkins Stuff
