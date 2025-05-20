#!/bin/bash
set -e

source config/setup.conf

get_cluster_node_names() {
    echo "$CONTROL_NODES $WORKER_NODES"
}

get_control_node_names() {
    echo "$CONTROL_NODES"
}

get_worker_node_names() {
    echo "$WORKER_NODES"
}

check_requirements() {
    local missing_tools=()
    
    if ! command -v colima &> /dev/null; then
        missing_tools+=("colima")
    fi
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    if ! command -v multipass &> /dev/null; then
        missing_tools+=("multipass")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        printf "❌ Missing required tools: ${missing_tools[*]}\n"
        printf "Please install before continuing.\n"
        exit 1
    fi
}

ensure_colima_running() {
    if ! colima status &>/dev/null; then
        if ! colima start --cpu $COLIMA_CPUS --memory $COLIMA_MEMORY --disk $COLIMA_DISK; then
            printf "\r%-${COLUMNS:-$(tput cols)}s" "❌ Failed to start Colima"
            exit 1
        fi
        spin='-\|/'
        i=0
        for ((n=0; n<10; n++)); do
            printf "\r%-${COLUMNS:-$(tput cols)}s" "⏰ Waiting for Colima to initialise... [${spin:i++%${#spin}:1}]"
            sleep 1
        done
        printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ Colima initialised"
    else
        printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ Colima is already running"
    fi
    local max_attempts=5
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if docker info &>/dev/null; then
            printf "✅ Docker is ready\n"
            return 0
        fi
        printf "\r%-${COLUMNS:-$(tput cols)}s\r"
        printf "⏰ Waiting for Docker to be ready... ($attempt/$max_attempts)"
        sleep 1
        attempt=$((attempt + 1))
    done
    printf "\r%-${COLUMNS:-$(tput cols)}s" "❌ Docker did not become ready in time"
    exit 1
}

create_vms() {
    printf "Creating Control Node VMs..."
    for node in $(get_control_node_names); do
        if ! multipass info $node >/dev/null 2>&1; then
            multipass launch --name $node \
                           --memory $CONTROL_NODE_MEMORY \
                           --cpus $CONTROL_NODE_CPUS \
                           --disk $CONTROL_NODE_DISK
        else
            printf "\r%-${COLUMNS:-$(tput cols)}s" "❌ Control Node VM $node already exists"
            exit 1
        fi
    done
    printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ Control Node VMs are running"

    printf "Creating Worker Node VMs..."
    for node in $(get_worker_node_names); do
        if ! multipass info $node >/dev/null 2>&1; then
            multipass launch --name $node \
                           --memory $WORKER_NODE_MEMORY \
                           --cpus $WORKER_NODE_CPUS \
                           --disk $WORKER_NODE_DISK
        else
            printf "\r%-${COLUMNS:-$(tput cols)}s" "❌ Worker Node VM $node already exists"
            exit 1
        fi
    done
    printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ Worker Node VMs are running"
}

setup_storage(){
    for node in $(get_worker_node_names); do
        printf "\nConfiguring storage on $node..."
        multipass exec $node -- sudo bash -c '
            mkdir -p /mnt/local-storage
            chmod 777 /mnt/local-storage
        '
        printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ Local storage configured on $node"
    done
}

setup_ssh() {
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi

    for node in $(get_cluster_node_names); do
        IP=$(multipass info $node | grep IPv4 | awk '{print $2}')
        printf "\nSetting up SSH for $node ($IP)..."
        
        # Clear any existing known hosts entry
        ssh-keygen -R $IP >/dev/null 2>&1
        
        # Add to known_hosts
        ssh-keyscan -H $IP >> ~/.ssh/known_hosts 2>/dev/null
        
        # Setup SSH access
        multipass exec $node -- sudo bash -c '
            mkdir -p /home/ubuntu/.ssh
            chmod 700 /home/ubuntu/.ssh
        '
        
        # Copy SSH key
        multipass transfer ~/.ssh/id_rsa.pub $node:/tmp/id_rsa.pub
        
        # Setup authorized_keys
        multipass exec $node -- sudo bash -c '
            cat /tmp/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys
            chmod 600 /home/ubuntu/.ssh/authorized_keys
            chown -R ubuntu:ubuntu /home/ubuntu/.ssh
        '
        
        # Verify SSH access
        if ssh -o BatchMode=yes -o ConnectTimeout=5 ubuntu@$IP echo "SSH connection successful for $node" > /dev/null; then
            printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ SSH setup verified for $node"
        else
            printf "\r%-${COLUMNS:-$(tput cols)}s" "❌ SSH setup failed for $node"
            exit 1
        fi
    done
}

update_inventory() {
    printf "\nPreparing Ansible inventory for Kubespray..."
    mkdir -p inventory/group_vars/k8s_cluster
    cp config/ansible/hosts.yml inventory/
    cp config/ansible/k8s_cluster.yml inventory/group_vars/k8s_cluster/
    cp config/ansible/addons.yml inventory/group_vars/k8s_cluster/

    for node in $(get_cluster_node_names); do
        IP=$(multipass info $node | grep IPv4 | awk '{print $2}')
        sed -i.bak "s|^      ansible_host: .*# $node\$|      ansible_host: $IP # $node|" inventory/hosts.yml
        sed -i.bak "s|^      ip: .*# $node\$|      ip: $IP # $node|" inventory/hosts.yml
        sed -i.bak "s|^      access_ip: .*# $node\$|      access_ip: $IP # $node|" inventory/hosts.yml
    done
    rm inventory/hosts.yml.bak
    printf "\r%-${COLUMNS:-$(tput cols)}s" "✅ Ansible inventory ready"
}

main() {
    check_requirements
    ensure_colima_running
    create_vms
    setup_storage
    setup_ssh
    update_inventory

    printf "\n"
    printf "\n=========================================="
    printf "\n 🏆 Initial setup complete! Next steps... "
    printf "\n=========================================="
    printf "\n"
    printf "\n1. Open VS Code in project directory"
    printf "\n2. When prompted, click 'Reopen in Container'"
    printf "\n3. Watch logs in DevContainer to follow cluster deployment"
    printf "\n "
    printf "\n"
}

main