#!/bin/bash
set -e

verify_kubectl_access() {
    echo "Verifying cluster accessibility..."
    
    local control_ip=$(yq '.all.hosts | with_entries(select(.key == "control-01")) | .["control-01"].access_ip' inventory/hosts.yml)

    mkdir -p ~/.kube
 
    echo "Copying kubeconfig from control plane..."
    ssh ubuntu@${control_ip} "sudo cat /etc/kubernetes/admin.conf" > ~/.kube/config
    chmod 600 ~/.kube/config

    kubectl config use-context kubernetes-admin@cluster.local

    kubectl config set-cluster cluster.local \
        --server=https://${control_ip}:6443 \
        --kubeconfig=$HOME/.kube/config

    echo "Verifying cluster access..."
    if timeout 5s kubectl cluster-info >/dev/null 2>&1; then
        echo -e "\n✅ $(kubectl cluster-info)"
        echo -e "\nCurrent context: $(kubectl config current-context)"
        return 0
    else
        echo "❌ Cannot connect to cluster"
        return 1
    fi
}

get_dashboard_token() {

  # Get the service account name
  SA_NAME=$(kubectl get serviceaccount -n kubernetes-dashboard kubernetes-dashboard -o jsonpath='{.metadata.name}')

  # Create a token for the service account if it doesn't exist
  if ! kubectl get secret -n kubernetes-dashboard kubernetes-dashboard-token &>/dev/null; then
    echo "Creating token for dashboard service account..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kubernetes-dashboard-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: ${SA_NAME}
type: kubernetes.io/service-account-token
EOF
  fi

  # Give dashboard cluster-admin access (acceptable for a dev cluster)
  if ! kubectl get clusterrolebinding kubernetes-dashboard-admin &>/dev/null; then
    kubectl create clusterrolebinding kubernetes-dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:kubernetes-dashboard
  fi

  # Get the token
  TOKEN=$(kubectl get secret kubernetes-dashboard-token -n kubernetes-dashboard -o jsonpath='{.data.token}' | base64 --decode)

  # Get dashboard URL
  NODE_PORT=$(kubectl get svc kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.spec.ports[0].port}')
  NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' | cut -d' ' -f1)

  echo -e "\nDashboard is available at: https://$NODE_IP:$NODE_PORT"
  echo -e "\n\033[0mTo use port-forwarding, run: \033[0;32mkubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443"
  echo -e "\n\033[0m...then browse to: \033[0;33mhttps://localhost:8443\033[0m"
  echo -e "\nUse this token to log in:"
  echo -e "\n\033[0;36m$TOKEN\n\033[0m\n"
}

verify_kubectl_access
get_dashboard_token