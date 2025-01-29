#!/bin/bash
set -e

source config/setup.conf

get_cluster_node_names() {
    echo "$CONTROL_NODES $WORKER_NODES"
}

printf "\nDeleting multipass VMs..."
for node in $(get_cluster_node_names); do
    if multipass info $node &>/dev/null; then
        printf "\nDeleting $node..."
        multipass delete $node
    else
        printf "\nVM $node does not exist, skipping"
    fi
done

if multipass list | grep -q "Deleted"; then
    printf "\nPurging deleted instances..."
    multipass purge
else
    printf "\nNo deleted instances to purge"
fi

printf "\nRemoving kubespray repo..."
rm -rf kubespray

printf "\nStopping colima..."
colima stop

printf "✅ Done!\n"
