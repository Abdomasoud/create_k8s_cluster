#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

echo "Disabling swap..."
sudo swapoff -a
sudo sed -i "/ swap / s/^/#/" /etc/fstab

echo "Installing containerd.io..."
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt install -y containerd.io

echo "Configuring containerd..."
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

echo "Restarting containerd..."
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "Adding kernel modules..."
sudo tee /etc/modules-load.d/k8s.conf > /dev/null <<EOF
br_netfilter
overlay
EOF

sudo modprobe br_netfilter
sudo modprobe overlay

echo "Adding sysctl parameters for Kubernetes..."
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

echo "Disabling UFW (Uncomplicated Firewall)..."
sudo ufw disable

echo "Installing apt-transport-https, ca-certificates, curl..."
sudo apt install -y apt-transport-https ca-certificates curl

echo "Adding Kubernetes apt key..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "Adding Kubernetes apt repository..."
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

echo "Updating apt cache after adding Kubernetes repo..."
sudo apt update

echo "Installing kubelet, kubeadm, kubectl..."
sudo apt install -y kubelet kubeadm kubectl

echo "Holding kubelet, kubeadm, kubectl versions..."
sudo apt-mark hold kubelet kubeadm kubectl

echo "Enabling and starting kubelet..."
sudo systemctl enable kubelet
sudo systemctl start kubelet

echo "Common prerequisites script completed."


