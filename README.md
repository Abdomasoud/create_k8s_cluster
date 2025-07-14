# Kubernetes Cluster Setup Guide (Ubuntu 24)

## 1. Introduction

This guide provides comprehensive instructions for setting up a Kubernetes cluster with one master node and two worker nodes on Ubuntu 24. It covers system requirements, best practices, and a step-by-step installation process.

## 2. Kubernetes Cluster Requirements

### 2.1. General Requirements

Based on various sources, here are the general recommendations for Kubernetes cluster nodes:

*   **Operating System:** Ubuntu 24 (as specified by the user).
*   **CPU:** At least 2 physical CPU cores per node. For the master node, more CPU is recommended (e.g., 4-8 cores) for better performance, especially in production environments.
*   **RAM:**
    *   **Master Node:** Minimum 8GB RAM. For production, 16GB or more is highly recommended.
    *   **Worker Nodes:** Minimum 4GB RAM per worker node. More RAM is beneficial depending on the workloads.
*   **Disk Space:** At least 20GB of free disk space per node. For production, consider SSDs for better I/O performance.
*   **Network:** Gigabit Ethernet for smooth networking between nodes. All nodes must have full network connectivity to each other.

### 2.2. Best Practices (Initial Overview)

Here's an initial overview of best practices for Kubernetes, which will be expanded upon later:

*   **Production Environments:** For production, it's generally recommended to have at least 3 master nodes for high availability. However, for this guide, we will focus on a 1-master, 2-worker setup as requested.
*   **Workload Separation:** Avoid running user workloads on master nodes in a production environment.
*   **Resource Management:** Utilize resource requests and limits for pods to ensure efficient resource allocation and prevent resource starvation.
*   **Networking:** Ensure proper network configuration and consider a robust Container Network Interface (CNI) plugin.
*   **Security:** Implement Role-Based Access Control (RBAC), avoid exposing the Kubernetes API server to the internet, and use secure communication.
*   **Monitoring and Logging:** Set up comprehensive monitoring and logging solutions for cluster health and application performance.
*   **Autoscaling:** Implement autoscaling for nodes and pods to handle varying workloads efficiently.
*   **Namespaces:** Use namespaces to organize resources and provide logical isolation.
*   **Probes:** Configure liveness and readiness probes for applications to ensure their health and availability.




### 2.3. Hardware Requirements (Detailed)

For a Kubernetes cluster with 1 master and 2 worker nodes, the following hardware specifications are recommended:

| Node Type | Minimum CPU Cores | Recommended CPU Cores | Minimum RAM | Recommended RAM | Minimum Disk Space | Recommended Disk Type |
|---|---|---|---|---|---|---|
| Master Node | 2 | 4-8+ | 8GB | 16GB+ | 20GB | SSD |
| Worker Node | 2 | 4+ | 4GB | 8GB+ | 20GB | SSD |

These recommendations are for a basic setup. For production environments or clusters with heavy workloads, consider scaling these resources up significantly.

### 2.4. Software Prerequisites (Ubuntu 24)

Before installing Kubernetes components, ensure the following software prerequisites are met on all nodes (master and workers):

*   **Operating System:** Ubuntu 24 LTS (64-bit).
*   **Container Runtime:** Kubernetes requires a container runtime to run containers. Popular choices include containerd, CRI-O, or Docker Engine. Containerd is the default and recommended runtime for Kubernetes.
*   **Network Connectivity:** All nodes must have full network connectivity to each other. This includes allowing necessary ports for Kubernetes components (e.g., 6443 for API server, 10250 for Kubelet).
*   **Swap Disabled:** Kubernetes does not officially support swap. It must be disabled on all nodes for kubelet to function correctly.
*   **Unique Hostnames:** Each node in the cluster must have a unique hostname.
*   **MAC Address and product_uuid:** The `kubelet` uses these values to identify nodes. It is possible that some virtual machines have the same MAC addresses and `product_uuid`s. You can use `ip link` or `ifconfig -a` to check the MAC addresses and `sudo cat /sys/class/dmi/id/product_uuid` to check the `product_uuid`.
*   **Required Ports:** Ensure the necessary ports are open on all nodes. A detailed list of ports will be provided in the installation section.





### 2.5. Detailed Port Requirements

To ensure proper communication within the Kubernetes cluster, the following ports must be open on your firewall:

| Protocol | Direction | Port(s) | Purpose | Node(s) |
|---|---|---|---|---|
| TCP | Inbound | 6443 | Kubernetes API server | Master |
| TCP | Inbound | 2379-2380 | etcd server client API | Master |
| TCP | Inbound | 10250 | Kubelet API | All |
| TCP | Inbound | 10259 | kube-scheduler | Master |
| TCP | Inbound | 10257 | kube-controller-manager | Master |
| TCP | Inbound | 30000-32767 | NodePort Services (default range) | All |

For worker nodes, the following ports are typically required:

| Protocol | Direction | Port(s) | Purpose | Node(s) |
|---|---|---|---|---|
| TCP | Inbound | 10250 | Kubelet API | Worker |
| TCP | Inbound | 30000-32767 | NodePort Services (default range) | Worker |

**Note:** These are the default ports. If you configure Kubernetes to use different ports, adjust your firewall rules accordingly. Additionally, your chosen Container Network Interface (CNI) plugin may require opening additional ports.





## 3. Installation and Configuration Guide

This section outlines the step-by-step process to install and configure your Kubernetes cluster on Ubuntu 24.

### 3.1. Pre-installation Steps (All Nodes)

Perform these steps on all master and worker nodes.

#### 3.1.1. Update System Packages

It's crucial to start with an up-to-date system. Run the following commands to update and upgrade your system packages:

```bash
sudo apt update
sudo apt upgrade -y
```

#### 3.1.2. Disable Swap

Kubernetes requires swap to be disabled. To temporarily disable swap, run:

```bash
sudo swapoff -a
```

To permanently disable swap, you need to comment out the swap entry in the `/etc/fstab` file. Open the file with a text editor:

```bash
sudo nano /etc/fstab
```

Find the line that contains `swap` (e.g., `/swapfile none swap sw 0 0` or a line referencing a swap partition) and add a `#` at the beginning of the line to comment it out. Save and exit the file.

#### 3.1.3. Install Container Runtime (Containerd)

Containerd is the recommended container runtime for Kubernetes. Install it using the following commands:

```bash
sudo apt install -y containerd.io
```

After installation, configure containerd to use `systemd` as the cgroup driver. First, generate the default containerd configuration file:

```bash
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

Now, edit the `config.toml` file to change the `SystemdCgroup` to `true`:

```bash
sudo nano /etc/containerd/config.toml
```

Locate the `[plugins.


io.containerd.grpc.v1.cri]` section and set `SystemdCgroup = true`.

```toml
[plugins."io.containerd.grpc.v1.cri"]
  ... (other configurations)
  [plugins."io.containerd.grpc.v1.cri".containerd]
    ... (other configurations)
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      ... (other configurations)
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true
```

After modifying the file, restart containerd:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

#### 3.1.4. Add Kernel Parameters

Enable kernel modules and configure sysctl parameters required by Kubernetes. Create a new file for Kubernetes sysctl settings:

```bash
sudo nano /etc/sysctl.d/k8s.conf
```

Add the following content to the file:

```
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

Load the new sysctl settings:

```bash
sudo sysctl --system
```

Ensure `br_netfilter` and `overlay` modules are loaded:

```bash
sudo modprobe br_netfilter
sudo modprobe overlay
```

To make these changes persistent across reboots, add them to `/etc/modules-load.d/k8s.conf`:

```bash
sudo nano /etc/modules-load.d/k8s.conf
```

Add the following lines:

```
br_netfilter
overlay
```

#### 3.1.5. Disable Firewall (UFW)

For simplicity in this guide, we will disable the UFW firewall. In a production environment, it is highly recommended to configure firewall rules to allow only necessary ports.

```bash
sudo ufw disable
```





#### 3.1.6. Install kubeadm, kubelet, and kubectl

These are the core Kubernetes tools. `kubeadm` is used to bootstrap the cluster, `kubelet` runs on all nodes and manages pods, and `kubectl` is the command-line tool for interacting with the cluster.

First, add the Kubernetes `apt` repository:

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
```

Now, install the Kubernetes components:

```bash
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

`apt-mark hold` prevents these packages from being automatically upgraded, which is important for maintaining cluster stability.

### 3.2. Master Node Initialization

Perform these steps only on your designated master node.

#### 3.2.1. Initialize the Kubernetes Control Plane

Use `kubeadm init` to initialize the master node. You need to specify the Pod network CIDR. A common choice is `10.244.0.0/16` for Flannel, or `192.168.0.0/16` for Calico. We will use `10.244.0.0/16` for this guide.

```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

After the initialization completes, you will see output similar to this:

```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a Pod network to the cluster. Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

  kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

**Important:** Copy the `kubeadm join` command output. You will need it to join the worker nodes to the cluster. Also, execute the commands provided to set up `kubectl` for your regular user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 3.2.2. Deploy a Pod Network (CNI Plugin)

After initializing the master node, you need to deploy a Pod network add-on. This is crucial for Pod-to-Pod communication. We will use Flannel as the CNI plugin.

```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

Verify that the Pods are running:

```bash
kubectl get pods --all-namespaces
```

You should see `kube-flannel-` pods and other core Kubernetes pods in a `Running` state.





### 3.3. Worker Node Joining

Perform these steps on each of your worker nodes.

#### 3.3.1. Join the Cluster

On each worker node, execute the `kubeadm join` command that was provided after the master node initialization. It will look something like this:

```bash
sudo kubeadm join <control-plane-host>:<control-plane-port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>
```

Replace `<control-plane-host>:<control-plane-port>`, `<token>`, and `<hash>` with the actual values from your master node initialization output.

After running the command, the worker node will connect to the master node and join the cluster.

#### 3.3.2. Verify Node Status (from Master Node)

From your master node, you can verify that the worker nodes have successfully joined the cluster by running:

```bash
kubectl get nodes
```

You should see your master node and both worker nodes listed with a `Ready` status.





## 4. Troubleshooting and Best Practices

### 4.1. Common Troubleshooting Tips

Here are some common issues you might encounter and how to troubleshoot them:

*   **Pods stuck in `Pending` state:**
    *   Check `kubectl describe pod <pod-name>` for events and error messages.
    *   Ensure there are enough resources (CPU, memory) on your worker nodes.
    *   Verify that the CNI plugin (Flannel) is correctly installed and running (`kubectl get pods -n kube-system`).
    *   Check `kubelet` logs on the node where the pod is scheduled (`sudo journalctl -u kubelet`).

*   **Nodes not in `Ready` state:**
    *   Check `kubelet` logs on the affected node (`sudo journalctl -u kubelet`). Look for errors related to container runtime, network, or API server connectivity.
    *   Verify that swap is disabled (`sudo swapon --show`).
    *   Ensure all required ports are open on the firewall.
    *   Check network connectivity between the master and worker nodes.

*   **`kubeadm init` or `kubeadm join` failures:**
    *   Ensure swap is disabled.
    *   Verify that `containerd` is running and configured correctly (especially the `SystemdCgroup` setting).
    *   Check for unique hostnames and correct `/etc/hosts` entries.
    *   Ensure the `kubeadm join` command is copied exactly, including the token and hash.
    *   Check `kubeadm` logs for more detailed error messages.

*   **`kubectl` not working:**
    *   Ensure your `KUBECONFIG` environment variable is set correctly or that the `admin.conf` file is copied to `$HOME/.kube/config` with correct permissions.
    *   Verify network connectivity to the Kubernetes API server (port 6443 on the master node).

### 4.2. Best Practices for a Production Kubernetes Cluster

While this guide focuses on a basic setup, consider these best practices for a production-ready Kubernetes cluster:

*   **High Availability:** For production, deploy at least three master nodes to ensure high availability of the control plane. This prevents a single point of failure.
*   **Resource Management:**
    *   **Resource Requests and Limits:** Always define resource requests and limits for your containers. Requests ensure that a container gets the minimum resources it needs, while limits prevent a container from consuming too many resources and impacting other workloads.
    *   **Quality of Service (QoS) Classes:** Understand and utilize Kubernetes QoS classes (Guaranteed, Burstable, BestEffort) to prioritize workloads.
*   **Security:**
    *   **Role-Based Access Control (RBAC):** Implement strict RBAC policies to control who can access the Kubernetes API and what actions they can perform.
    *   **Network Policies:** Use Network Policies to control traffic flow between pods and namespaces, enhancing security and isolation.
    *   **Secrets Management:** Use Kubernetes Secrets or a dedicated secrets management solution (e.g., HashiCorp Vault) to store sensitive information securely.
    *   **Image Security:** Use trusted container images and regularly scan them for vulnerabilities.
    *   **API Server Access:** Restrict access to the Kubernetes API server. Avoid exposing it directly to the public internet. Use a VPN or bastion host for administrative access.
    *   **Pod Security Standards (PSS):** Implement PSS to enforce security best practices for pods.
*   **Networking:**
    *   **Choose a Robust CNI:** Select a CNI plugin that meets your network requirements, considering features like network policies, IP address management, and performance.
    *   **DNS:** Ensure robust DNS resolution within the cluster for service discovery.
*   **Monitoring and Logging:**
    *   **Centralized Logging:** Implement a centralized logging solution (e.g., ELK stack, Grafana Loki) to collect and analyze logs from all cluster components and applications.
    *   **Monitoring:** Use monitoring tools (e.g., Prometheus, Grafana) to collect metrics on cluster health, resource utilization, and application performance. Set up alerts for critical events.
*   **Storage:**
    *   **Persistent Storage:** For stateful applications, use Persistent Volumes (PVs) and Persistent Volume Claims (PVCs) with a suitable StorageClass (e.g., NFS, Ceph, cloud provider storage) to ensure data persistence.
*   **Upgrades and Maintenance:**
    *   **Regular Updates:** Keep your Kubernetes cluster and underlying operating system updated to benefit from new features, bug fixes, and security patches.
    *   **Backup and Restore:** Implement a strategy for backing up and restoring your cluster's etcd data and persistent volumes.
*   **Automation:** Automate cluster deployment, configuration, and management tasks using tools like Ansible, Terraform, or GitOps principles.
*   **Documentation:** Maintain comprehensive documentation of your cluster's configuration, deployment procedures, and operational guidelines.
