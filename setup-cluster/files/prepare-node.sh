#!/bin/bash
set -eio -pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR

# 
# This script is intended to run on the host to install 
# all the necessary stuff and also reconfigure it so it is ready for
# kubernetes to run
#

KUBERNETES_VERSION=1.12.0-00

# 
# Prepare apt
#
apt-get update
sudo apt-get install -y software-properties-common

#
# Disable Swap, 
# (not necessary on aws debian images)
#
swapoff -a
perl -pi -e 's/^LABEL=swap/#LABEL=swap/g'  /etc/fstab


#
# Install a kubernetes-compatible version of docker
#
apt-get remove -y docker-engine
apt-get purge -y docker-engine


apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository \
   "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") \
   $(lsb_release -cs) \
   stable"
apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 18.06 | head -1 | awk '{print $3}')
apt-get install -y nfs-common

# 
# /var is on its own tiny root partition, there is a big EBS volume
# attached at xvdb
# Mount the EBS volume xvdb to /var-alt to hold the big stuff
# see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ebs-using-volumes.html
#
mounted_varalt=$(lsblk | grep '/var-alt' )
if [[ ! -z "${$mounted_varalt}" ]] ; then 

  file -s /dev/xvdb
  mkfs -t ext4 /dev/xvdb
  mkdir /var-alt
  mount /dev/xvdb /var-alt
  device_uuid=$(file -s /dev/xvdb | perl -n -e '/UUID=((\w|-)+)/ && print $1;')
  echo "UUID=$device_uuid   /var-alt   ext4   rw,discard,errors=remount-ro    0    1" >> /etc/fstab
fi

#
# set up a home for /var/lib/docker and /var/lib/kubelet on the root partition
# so that we have more room to move.
#
mkdir -p /var-alt/lib/docker
cat << EOF > /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"],
  "graph": "/var-alt/lib/docker"
}
EOF

# 
# Install docker cleanup hourly cron job to remove unused images and volumes
# Note... the files in /etc/cron.daily must not contain the '.' character. 
#
cp docker-cleanup2 /etc/cron.hourly/docker-cleanup2
chmod a+x /etc/cron.daily/docker-cleanup2

#
# prepare systemd setup files for /var-alt/lib/kubelet
# and create symlink from /var/lib/kubelet -> /var-alt/lib/kubelet
# 
rm -rf  /var/lib/kubelet
rm -rf  /var-alt/lib/kubelet

mkdir -p /var-alt/lib/kubelet
ln -s /var-alt/lib/kubelet /var/lib/kubelet
mkdir -p /etc/systemd/system/kubelet.service.d/

#
# This didn't work
#

# cat <<EOM > /etc/systemd/system/kubelet.service.d/20-kube_home.conf
# [Service]
# Environment="KUBELET_EXTRA_ARGS=--root-dir /var-alt/lib/kubelet"
# EOM

# 
# Install kubeadm and kubelet dependencies. 
# This script locks in a particular version of kubernetes tools so that 
# it will behave the same no matter what. 
#
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get remove --purge -y kubelet kubeadm kubectl
apt-get install -y --allow-downgrades kubelet=$KUBERNETES_VERSION kubeadm=$KUBERNETES_VERSION kubectl=$KUBERNETES_VERSION

#
# Load the kernel modules for modprobe
#
modprobe -- ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh

systemctl daemon-reload
systemctl restart docker

# 
# After all updates, reboot to put the correct settings into resolv.conf
#
