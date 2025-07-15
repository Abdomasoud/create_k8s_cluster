#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Initializing Kubernetes control plane..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

echo "Configuring kubectl for ubuntu user..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Deploying Flannel CNI network..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "Getting kubeadm join command..."
sudo kubeadm token create --print-join-command > /home/ubuntu/join_command.sh
chmod +x /home/ubuntu/join_command.sh

echo "Master node configuration script completed."


