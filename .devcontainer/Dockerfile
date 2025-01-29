FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release && \
    # Kubernetes repo
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list && \
    # Helm repo
    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor > /etc/apt/keyrings/helm.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" > /etc/apt/sources.list.d/helm-stable-debian.list

RUN apt-get update && apt-get install -y \
    git \
    curl

RUN apt-get install -y \
    python3 \
    python3-pip \
    ansible \
    openssh-client

RUN apt-get install -y \    
    tmux \
    kubectl \
    helm \
    bash-completion

RUN apt-get install -y \
    vim \
    wget \
    netcat \
    dnsutils \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

RUN wget https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64 -q -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

RUN pip3 install --no-cache-dir netaddr jinja2

RUN echo 'source <(kubectl completion bash)' >> /root/.bashrc && \
    echo 'source <(helm completion bash)' >> /root/.bashrc && \
    echo 'alias k=kubectl' >> /root/.bashrc && \
    echo 'complete -F __start_kubectl k' >> /root/.bashrc
    
ENV SHELL /bin/bash

#redundant but prevents devcontainer from skipping postCreate command
RUN mkdir -p /root/.kube /root/.helm 