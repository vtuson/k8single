#!/bin/bash

CIDR="192.168.0.0/16"

echo "installing system dependencies for Ubuntu 16.04+"

sudo apt-get update
sudo apt-get install -y docker.io

sudo apt-get update && sudo apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF >/tmp/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo cp /tmp/kubernetes.list /etc/apt/sources.list.d/
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

echo "running init on kubeadm with $CIDR pod network"
sudo kubeadm init --pod-network-cidr=$CIDR

echo "configuring kubectl"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "configuring networking"
sudo sysctl net.bridge.bridge-nf-call-iptables=1
export kubever=$(kubectl version | base64 | tr -d '\n')
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"
kubectl taint nodes --all node-role.kubernetes.io/master-




