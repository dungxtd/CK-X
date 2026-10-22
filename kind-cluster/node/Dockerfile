# Exam node image: the kind node plus an SSH server, so candidates can
# `ssh <node>` from the jumphost and work on kubelet, static pods and
# /etc/kubernetes like on the real exam. Built inside the dind daemon by
# entrypoint.sh (cached on the dind-data volume).
ARG BASE
FROM ${BASE}

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-server \
 && rm -rf /var/lib/apt/lists/* \
 && passwd -d root \
 && printf '%s\n' 'PermitRootLogin yes' 'PermitEmptyPasswords yes' 'UsePAM no' \
      > /etc/ssh/sshd_config.d/ckx.conf \
 && systemctl enable ssh \
 && echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /root/.bashrc
