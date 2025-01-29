#!/bin/bash
set -e

source config/setup.conf

get_cluster_node_names() {
    echo "$CONTROL_NODES $WORKER_NODES"
}

configure_docker() {
    echo "Configuring Docker..."
    mkdir -p /root/.docker
    cat > /root/.docker/config.json <<EOF
{
    "credHelpers": {},
    "credsStore": ""
}
EOF
}

configure_ssh() {
    echo "Configuring SSH..."
    mkdir -p /root/.ssh
    cp -r /tmp/.ssh/* /root/.ssh/
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/*
    cat > /root/.ssh/config <<EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    User ubuntu
    IdentityFile /root/.ssh/id_rsa
EOF
    chmod 600 /root/.ssh/config
}

verify_ssh() {
    echo "Verifying SSH access to nodes..."
    for node in $(get_cluster_node_names); do
        IP=$(grep "ansible_host.*#.*$node" /workspace/inventory/hosts.yml | awk '{print $2}')
        echo "Testing SSH connection to $node ($IP)..."
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 ubuntu@$IP echo "✅ SSH connection successful for $node"; then
            echo "❌ Cannot SSH to $node ($IP)"
            echo "Please verify SSH setup and network connectivity"
            exit 1
        fi
    done
}

clone_kubespray() {
    echo "Cloning Kubespray repository..."
    if [ -d "kubespray" ]; then
        echo "Kubespray directory exists, cleaning up..."
        rm -rf kubespray
    fi
    git clone https://github.com/kubernetes-sigs/kubespray.git
    echo "✅ Cloned Kubespray repository"
}

bootstrap_cluster() {
    echo "Setting up Ansible inventory..."
    mkdir -p kubespray/inventory/mycluster/
    cp -r /workspace/inventory/* kubespray/inventory/mycluster/
    echo "✅ Prepared Ansible inventory"

    echo "Installing Python requirements..."
    cd kubespray
    pip install -r requirements.txt
    echo "✅ Installed Python requirements"

    echo "Starting Kubernetes deployment..."
    cd /workspace/kubespray
    ANSIBLE_ROLES_PATH=/workspace/kubespray/roles ansible-playbook -i inventory/mycluster/hosts.yml cluster.yml -b
    echo "✅ Completed Kubernetes deployment"
}

configure_docker
configure_ssh
verify_ssh
clone_kubespray
bootstrap_cluster