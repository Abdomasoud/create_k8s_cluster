# Kubernetes Cluster Setup on AWS EC2 with Bash Scripts

This repository provides a set of bash scripts to automate the deployment of a Kubernetes cluster (1 master, 2 workers) on Ubuntu 24 LTS EC2 instances in AWS.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Scripts Overview](#scripts-overview)
- [Usage Guide](#usage-guide)
  - [Step 1: Provision EC2 Instances](#step-1-provision-ec2-instances)
  - [Step 2: Run Common Prerequisites Script](#step-2-run-common-prerequisites-script)
  - [Step 3: Run Master Configuration Script](#step-3-run-master-configuration-script)
  - [Step 4: Copy Join Command to Workers](#step-4-copy-join-command-to-workers)
  - [Step 5: Run Worker Configuration Script](#step-5-run-worker-configuration-script)
- [Verifying the Cluster](#verifying-the-cluster)
- [Accessing the Cluster from Local Machine](#accessing-the-cluster-from-local-machine)
- [Important Notes](#important-notes)

## Prerequisites

Before using these scripts, ensure you have the following:

1.  **AWS Account:** An active AWS account.
2.  **EC2 Instances:** Three Ubuntu 24 LTS EC2 instances provisioned in AWS (1 for master, 2 for workers). It's recommended to place them in different Availability Zones for high availability.
    *   Ensure these instances have sufficient resources (e.g., `t3.medium` or larger).
    *   Ensure the security groups for these instances allow necessary traffic (SSH, Kubernetes ports).
3.  **SSH Key Pair:** An SSH key pair associated with your EC2 instances for secure access.
4.  **`kubectl` (Local Machine):** `kubectl` installed on your local machine if you plan to manage the cluster remotely.
5.  **`scp` (Local Machine):** `scp` client available on your local machine for copying files.

## Scripts Overview

This repository contains the following bash scripts in the `scripts/` directory:

*   `common_prerequisites.sh`: Sets up common prerequisites on all Kubernetes nodes (master and workers).
*   `master_configuration.sh`: Initializes the Kubernetes control plane on the master node.
*   `worker_configuration.sh`: Joins worker nodes to the Kubernetes cluster.

## Usage Guide

Follow these steps to set up your Kubernetes cluster.

### Step 1: Provision EC2 Instances

Provision your 3 EC2 instances (1 master, 2 workers) with Ubuntu 24 LTS. Ensure they are accessible via SSH using your key pair.

### Step 2: Run Common Prerequisites Script

This script must be run on **all three** EC2 instances (master and both workers).

1.  Copy `common_prerequisites.sh` to each instance:
    ```bash
    scp -i /path/to/your-key-pair.pem scripts/common_prerequisites.sh ubuntu@<instance_public_ip>:/home/ubuntu/
    ```
2.  SSH into each instance and execute the script:
    ```bash
    ssh -i /path/to/your-key-pair.pem ubuntu@<instance_public_ip>
    chmod +x common_prerequisites.sh
    sudo ./common_prerequisites.sh
    exit
    ```

### Step 3: Run Master Configuration Script

This script must be run only on your designated **master node**.

1.  Copy `master_configuration.sh` to the master instance:
    ```bash
    scp -i /path/to/your-key-pair.pem scripts/master_configuration.sh ubuntu@<master_public_ip>:/home/ubuntu/
    ```
2.  SSH into the master instance and execute the script:
    ```bash
    ssh -i /path/to/your-key-pair.pem ubuntu@<master_public_ip>
    chmod +x master_configuration.sh
    sudo ./master_configuration.sh
    ```
    This script will initialize the Kubernetes control plane and generate a `join_command.sh` file in `/home/ubuntu/` on the master node. This file contains the command needed for worker nodes to join the cluster.

### Step 4: Copy Join Command to Workers

After the master configuration is complete, copy the `join_command.sh` file from the master node to **each worker node**.

```bash
scp -i /path/to/your-key-pair.pem ubuntu@<master_public_ip>:/home/ubuntu/join_command.sh ubuntu@<worker_public_ip>:/home/ubuntu/
```
Repeat this for each worker node.

### Step 5: Run Worker Configuration Script

This script must be run on **each worker node**.

1.  Copy `worker_configuration.sh` to each worker instance:
    ```bash
    scp -i /path/to/your-key-pair.pem scripts/worker_configuration.sh ubuntu@<worker_public_ip>:/home/ubuntu/
    ```
2.  SSH into each worker instance and execute the script:
    ```bash
    ssh -i /path/to/your-key-pair.pem ubuntu@<worker_public_ip>
    chmod +x worker_configuration.sh
    sudo ./worker_configuration.sh
    exit
    ```

## Verifying the Cluster

After all scripts have been executed, you can verify the cluster status by SSHing into your master node and running:

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

You should see all your nodes in a `Ready` state and the core Kubernetes pods running.

## Accessing the Cluster from Local Machine

To manage your Kubernetes cluster from your local machine using `kubectl`:

1.  **Copy `kubeconfig`:** Copy the `admin.conf` file from your master node to your local machine. This file is located at `/etc/kubernetes/admin.conf` on the master node.
    ```bash
    scp -i /path/to/your-key-pair.pem ubuntu@<master_public_ip>:/etc/kubernetes/admin.conf $HOME/.kube/config
    ```
2.  **Set Permissions:** Secure the `kubeconfig` file:
    ```bash
    chmod 600 $HOME/.kube/config
    ```
3.  **Update Server Address:** The `kubeconfig` file on the master node uses its private IP. You need to update it to the master node's public IP for external access.
    ```bash
    kubectl config set-cluster kubernetes --server=https://<master_public_ip>:6443 --kubeconfig=$HOME/.kube/config
    ```
    Replace `<master_public_ip>` with the actual public IP of your master node.
4.  **Verify:** Test your connection:
    ```bash
    kubectl get nodes
    ```

## Important Notes

*   **Security:** The provided security group rules in the Terraform setup are broad for ease of use. For production environments, tighten ingress rules (especially for SSH and NodePort services) to specific IP ranges.
*   **`kubeadm` Version:** The scripts are configured for Kubernetes version `v1.29`. If you need a different version, adjust the Kubernetes apt repository URL in `common_prerequisites.sh`.
*   **`containerd.io`:** The `common_prerequisites.sh` script includes steps to add the Docker repository to correctly install `containerd.io`.
*   **Troubleshooting:** If you encounter issues, check the logs on the respective nodes (`sudo journalctl -u kubelet`, `sudo journalctl -u containerd`) and ensure all required ports are open.

---