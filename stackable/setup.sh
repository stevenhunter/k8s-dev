set -euo pipefail

# Make local-storage the default storage class
echo "Making local-storage the default storage class..."
kubectl patch storageclass local-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
echo "✅ Made local-storage the default storage class"

# Get worker node IP
echo "Getting worker node IP..."
WORKER_IP=$(kubectl get nodes -l kubernetes.io/hostname=worker-01 -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "✅ Got worker node IP: $WORKER_IP"

# Create static volumes and mount for local volume provisioner
echo "Creating static volumes and mounts for local volume provisioner..."
ssh -t ubuntu@$WORKER_IP << 'EOF'
echo "Creating parent directory for local storage..."
sudo mkdir -p /var/local-storage-data
echo "✅ Created parent directory for local storage"

echo "Creating local storage directories..."
for vol in vol1 vol2 vol3 vol4 vol5 vol6; do
    sudo mkdir -p /var/local-storage-data/$vol
    sudo chmod 755 /var/local-storage-data/$vol
done
echo "✅ Created local storage directories"

echo "Creating mount points for local storage..."
for vol in vol1 vol2 vol3 vol4 vol5 vol6; do
    # Recreate the mount target dirs if they were removed
    sudo mkdir -p /mnt/local-storage/$vol
    # Create bind mounts from your data directories
    sudo mount --bind /var/local-storage-data/$vol /mnt/local-storage/$vol
done
echo "✅ Created mount points for local storage"

echo "Fixing CRI-O configuration..."
sudo mkdir -p /etc/containers/registries.conf.d/
sudo tee /etc/containers/registries.conf.d/01-unqualified.conf << EOF1
unqualified-search-registries = ["docker.io"]
EOF1
echo "✅ Fixed CRI-O configuration"

sudo systemctl restart crio
echo "Restarted CRI-O service"
EOF
echo "✅ Created static volumes and mounts for local volume provisioner"

# Install stackablectl
echo "Installing stackablectl..."
curl -L -o stackablectl https://github.com/stackabletech/stackable-cockpit/releases/download/stackablectl-25.3.0/stackablectl-aarch64-unknown-linux-gnu
chmod +x stackablectl
mv stackablectl /usr/local/bin/
echo "✅ Installed stackablectl"

# Install demo
echo "Installing demo..."
stackablectl demo install trino-taxi-data
