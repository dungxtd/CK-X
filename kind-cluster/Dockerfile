FROM docker:dind

# Accept build-time architecture argument
ARG TARGETARCH

#install curl
RUN apk add --no-cache curl
# use our own to start kind cluster
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# persist existing entrypoint
RUN cp /usr/local/bin/dockerd-entrypoint.sh /usr/local/bin/startup.sh

#copy scripts
COPY scripts/ /usr/local/bin/

#make scripts executable
RUN chmod +x /usr/local/bin/env-setup /usr/local/bin/env-cleanup /usr/local/bin/etcd-export-certs

# Exam clusters are kind (kubeadm) clusters. Keep the node version in step
# with kubectl/etcdctl in jumphost/Dockerfile.
ENV KIND_VERSION=v0.33.0 \
    KUBECTL_VERSION=v1.35.8 \
    METRICS_SERVER_VERSION=v0.9.0 \
    KIND_NODE_IMAGE=kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0 \
    CKX_NODE_IMAGE=ckx/node:v1.35.8
# env-setup runs over ssh, which does not see the image ENV
RUN env | grep -E '^(KIND_NODE_IMAGE|CKX_NODE_IMAGE)=' > /etc/ckx.env

RUN arch="${TARGETARCH:-amd64}" \
 && curl -fsSLo /usr/local/bin/kind "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-${arch}" \
 && curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${arch}/kubectl" \
 && chmod +x /usr/local/bin/kind /usr/local/bin/kubectl

# Node image with sshd (built into dind on first start), containerd mirror
# config mounted into every node, and metrics-server (kind has none; the
# kubelet certs are self-signed, hence --kubelet-insecure-tls)
COPY node/ /usr/local/share/ckx/node/
COPY containerd/certs.d/ /usr/local/share/ckx/certs.d/
RUN curl -fsSL "https://github.com/kubernetes-sigs/metrics-server/releases/download/${METRICS_SERVER_VERSION}/components.yaml" \
      | sed 's/^\( *\)- --secure-port=10250$/&\n\1- --kubelet-insecure-tls/' \
      > /usr/local/share/ckx/metrics-server.yaml \
 && grep -q -- '--kubelet-insecure-tls' /usr/local/share/ckx/metrics-server.yaml

RUN apk add --no-cache openssh-server
RUN apk add bash 
RUN apk add openssh-server-pam

RUN ssh-keygen -A

# allow root ssh login without password 
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config
RUN sed -i 's/^#UsePAM yes/UsePAM no/' /etc/ssh/sshd_config

# create a non-login user for ssh access
RUN adduser -D -s /bin/bash candidate
RUN passwd -d candidate

# #set not password for candidate user
RUN echo "candidate::0:0:candidate:/home/candidate:/bin/bash" > /etc/passwd
RUN echo "candidate:x:1000:1000:candidate:/home/candidate:/bin/bash" >> /etc/passwd

# create a home directory for the candidate user
RUN mkdir -p /home/candidate
RUN chown -R candidate: /home/candidate

EXPOSE 6443
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]