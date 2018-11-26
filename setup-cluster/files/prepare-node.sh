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

KUBERNETES_VERSION=1.9.0-00

# 
# Remove hybris apt repository as it is broken
#


# broken repo list: 
# http://depot.fra.hybris.com/hybris
# http://depot.fra.hybris.com/hybris
# https://repository.hybris.com/docker-engine

cp /etc/apt/sources.list.d/jessie.list /etc/apt/sources.list.d/stretch.list
sed -i 's/jessie/stretch/g' /etc/apt/sources.list.d/stretch.list

rm -rf /etc/apt/sources.list.d/hybris.list \
    /etc/apt/sources.list.d/docker.list \
    /etc/apt/sources.list.d/wheezy.list \
    /etc/apt/sources.list.d/jessie.list

apt-get update
sudo apt-get install -y software-properties-common

#
# Disable Swap 
#
swapoff -a
perl -pi -e 's/^LABEL=swap/#LABEL=swap/g'  /etc/fstab

#
# disable systemd-resolved and resolvconf
# it plays havoc with kubedns
#
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl stop resolvconf.service
systemctl disable resolvconf.service

unlink /etc/resolv.conf || echo "ok"

#
# Put known-good internal nameservers into resolv.conf
#
cat > /etc/resolv.conf <<EOF
nameserver 10.27.224.242
nameserver 10.27.224.243
search prod.datahub.ecp.ydev.hybris.com yrdci.rot.hybris.com
EOF

#
# Disable ferm firewall since it interferes with kube networking
#
systemctl stop ferm.service
systemctl disable ferm.service

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
apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
apt-get install -y nfs-common

# 
# /var is on its own tiny partition
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

systemctl daemon-reload
systemctl restart docker

# 
# After all updates, reboot to put the correct settings into resolv.conf
#
