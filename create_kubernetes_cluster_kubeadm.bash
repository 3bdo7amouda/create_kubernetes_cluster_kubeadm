################################################
# Create K8S cluster using Kubeadm and Vagrant #
################################################

# prerequisits
# 	1- VirtualBox installed
# 	2- Vagrant installed

# Us the "Ex_Files_Kubernetes_Provisioning_With_Kubeadm" that containt the prerequisits to build VMs using Vagrant

# cd "OneDrive\Documents\Ex_Files_Kubernetes_Provisioning_With_Kubeadm\Ex_Files_Kubernetes_Provisioning_With_Kubeadm\Exercise Files\vms_before\intel\"
vagrant up
vagrant upload .\10-vm.node-a.network node-a
vagrant upload .\10-vm.node-b.network node-b

# Change the hostnames of the VMs and move the IP files to correct location
vagrant ssh node-a
sudo hostnamectl set-hostname node-a
sudo mv ./10-vm.node-a.network /etc/systemd/network/
sudo systemctl restart systemd-networkd

vagrant ssh node-b
hostnamectl set-hostname node-b
sudo hostnamectl set-hostname node-b
sudo mv ./10-vm.node-b.network /etc/systemd/network/
sudo systemctl restart systemd-networkd

# Test conection from each VM to the Other
# On node-a
ping -c5 192.168.64.9

# On node-b
ping -c5 192.168.64.8

# On both Nodes record the latest available release
version=$(curl -L https://dl.k8s.io/release/stable.txt)


# Now we need to download kubeadm, kubelet and kubectl on all nodes
sudo curl -L -o /usr/local/bin/kubeadm https://dl.k8s.io/release/$version/bin/linux/amd64/kubeadm

sudo curl -L -o /usr/local/bin/kubelet https://dl.k8s.io/release/$version/bin/linux/amd64/kubelet

sudo curl -L -o /usr/local/bin/kubectl https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl


# On all nodes make sure downloaded binaries are executable
sudo chmod +x /usr/local/bin/kube*

# Check if comamnds works ok
kubeadm version
kubectl version
kubelet --version


# Let's uplaod some config files
vagrant upload .\10-kubeadm.node-a.conf node-a
vagrant upload .\k8s.conf node-a
vagrant upload .\kubelet.service node-a

vagrant upload .\10-kubeadm.node-b.conf node-b
vagrant upload .\k8s.conf node-b
vagrant upload .\kubelet.service node-b


# Create a directory to host kubelet configs on all VMs
sudo mkdir -p /etc/systemd/system/kubelet.service.d

# On node-a
sudo cp -v 10-kubeadm.node-a.conf /etc/systemd/system/kubelet.service.d/

# On node-b
sudo cp -v 10-kubeadm.node-b.conf /etc/systemd/system/kubelet.service.d/

# On all nodes copy unit file that starts the kubelet
sudo cp -v kubelet.service /etc/systemd/system/

# To get new unit file into consideration relad daemons and enable kubelet service on all nodes
sudo systemctl daemon-reload
sudo systemctl enable --now kubelet


# Check the status of the kubelet.service
sudo systemctl status kubelet

# NOTICE that it is in failed state which is normal because we didn't run kubeadm init yet
'
vagrant@node-a:~$ sudo systemctl status kubelet
× kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/kubelet.service.d
             └─10-kubeadm.node-a.conf
     Active: failed (Result: exit-code) since Tue 2024-04-30 11:31:58 UTC; 14s ago
       Docs: https://kubernetes.io/docs/home/
    Process: 2730 ExecStart=/usr/local/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS (code=exited, status=1/FAILURE)
   Main PID: 2730 (code=exited, status=1/FAILURE)
        CPU: 1.827s

Apr 30 11:31:56 node-a systemd[1]: Started kubelet: The Kubernetes Node Agent.
Apr 30 11:31:58 node-a kubelet[2730]: E0430 11:31:58.114353    2730 run.go:74] "command failed" err="failed to load kubelet config file, path: /var/lib/kubelet/config.yaml, error: failed to load Kubelet config file /var/lib/kubelet/co>
Apr 30 11:31:58 node-a systemd[1]: kubelet.service: Main process exited, code=exited, status=1/FAILURE
Apr 30 11:31:58 node-a systemd[1]: kubelet.service: Failed with result 'exit-code'.
Apr 30 11:31:58 node-a systemd[1]: kubelet.service: Consumed 1.827s CPU time.
'

# Before we run kubeadm init we will need to download "Contaienr Runtime", "Container Runtime Client" and "Container Network Interface (CNI)" on all nodes
# 	"Contaienr Runtime" --> "containerd" --> https://github.com/containerd/containerd/releases
# 	"Container Runtime Client" --> "crictl" 
# 	"Container Network Interface (CNI)" --> "Antrea"
# We will be using containerd as a Container runtime

# On all nodes download containerd binary
curl -L https://github.com/containerd/containerd/releases/download/v1.7.16/containerd-1.7.16-linux-amd64.tar.gz -o /tmp/containerd.tar.gz

# On all nodes download containerd.service file from https://github.com/containerd/containerd/blob/main/containerd.service
sudo curl -L -o /etc/systemd/system/containerd.service https://raw.githubusercontent.com/containerd/containerd/main/containerd.service

# On all nodes download "crictl" from https://github.com/kubernetes-sigs/cri-tools/releases
curl -L https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz -o /tmp/crictl.tar.gz

# On all nodes download CNI
curl -L https://github.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz -o /tmp/cni.tar.gz

# Now let's instaleld tools we've dowloaded
pushd /usr/local/
sudo tar -xvf /tmp/containerd.tar.gz
popd
containerd --version


pushd /usr/local/bin
sudo tar -xvf /tmp/crictl.tar.gz
popd
crictl --version

sudo mkdir -p /opt/cni/bin
pushd /opt/cni/bin
sudo tar -xvf /tmp/cni.tar.gz
popd



# Now let's configure "Container Runtime"
sudo apt -y update
sudo apt -y install runc
sudo mkdir -p /etc/containerd
containerd config default > /tmp/config.toml
sudo mv /tmp/config.toml /etc/containerd


# One change we need to do on all nodes since we are using Ubuntu 22.04 which using the cgroups supported by systemd instead of cgroupv2
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Let's start Container Runtime
sudo systemctl daemon-reload
sudo systemctl enable --now containerd.service
systemctl status containerd

# Let's make sure that containerd is actually working
sudo ctr image pull docker.io/library/hello-world:latest
sudo ctr run --rm docker.io/library/hello-world:latest test


# Let's start creating the kubernetes cluster
# On all nodes
sudo kubeadm reset -f
sudo apt -y install socat conntrack
sudo swapoff -a && sudo systemctl mask swap.img.swap
sudo touch /etc/modules-load.d/k8s.conf /etc/sysctl.d/k8s.conf
sudo vim /etc/modules-load.d/k8s.conf /etc/sysctl.d/k8s.conf 
# And add below featuers to /etc/modules-load.d/k8s.conf
overlay
br_netfilter

# And add below featuers to /etc/sysctl.d/k8s.conf
# First two lines work togther with br_netfilter module to allow containers within pods to talk to each others
# Last line allows to send traffic to other machines (worker nodes)
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1

# Reboot both nodes
sudo reboot now

# On one node-a 
sudo kubeadm init phase preflight
# If you are annoyed with below  warning
W0430 13:25:12.493096    1021 checks.go:844] detected that the sandbox image "registry.k8s.io/pause:3.8" of the container runtime is inconsistent with that used by kubeadm.It is recommended to use "registry.k8s.io/pause:3.9" as the CRI sandbox image.

# modify the image tag on the "registry.k8s.io/pause:3.9" in /etc/containerd/config.toml and restart containerd

# Initialize the cluster and make note of the Kubeadm join command that is printed
sudo kubeadm init --apiserver-advertise-address 192.168.64.8 --pod-network-cidr 100.64.0.0/16

# If we checke dthe cluster nodes we can see that it is not ready because K8S doean't manage network
# Thats's why we need to use a CNI
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f https://github.com/antrea-io/antrea/releases/download/v2.0.0/antrea.yml

# Then join node-b to the cluster using the join command you got from kubeadm init command
# If you cant find it you can generate a new token and print the join command again as below on controler node 
sudo kubeadm token create --print-join-command
kubeadm join 192.168.64.8:6443 --token cjg38f.gt285c5qiulehpbm --discovery-token-ca-cert-hash sha256:f019423b209b49a21071cd8d37ffe6149fac8230a392dcee6129e1e88f9cf5e9 


# Let's do a smoke test by running a pod 
sudo kubectl --kubeconfig /etc/kubernetes/admin.conf run --rm --stdin --image=hello-world --restart=Never --request-timeout=30 test-pod 