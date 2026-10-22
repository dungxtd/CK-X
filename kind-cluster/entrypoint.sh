#!/bin/sh

# ===============================================================================
#   KIND Cluster Setup Entrypoint Script
#   Purpose: Initialize Docker and create Kind cluster
# ===============================================================================

echo "$(date '+%Y-%m-%d %H:%M:%S') | ===== INITIALIZATION STARTED ====="
echo "$(date '+%Y-%m-%d %H:%M:%S') | Executing container startup script..."

# Execute current entrypoint script
if [ -f /usr/local/bin/startup.sh ]; then
    sh /usr/local/bin/startup.sh &
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [INFO] Default startup script not found at /usr/local/bin/startup.sh"
fi

# ===============================================================================
#   Docker Readiness Check
# ===============================================================================

echo "$(date '+%Y-%m-%d %H:%M:%S') | Checking Docker service status..."
DOCKER_CHECK_COUNT=0

# Wait for docker to be ready
while ! docker ps; do   
    DOCKER_CHECK_COUNT=$((DOCKER_CHECK_COUNT+1))
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [WAITING] Docker service not ready yet... (attempt $DOCKER_CHECK_COUNT)"
    sleep 5
done

echo "$(date '+%Y-%m-%d %H:%M:%S') | [SUCCESS] Docker service is ready and operational"

#pull kindest/node image
# docker pull kindest/node:$KIND_DEFAULT_VERSION

#add user for ssh access
adduser -S -D -H -s /sbin/nologin -G sshd sshd

#start ssh service
/usr/sbin/sshd -D &

#install k3d
echo "$(date '+%Y-%m-%d %H:%M:%S') | [INFO] Installing k3d"
TAG=v5.8.3 bash /usr/local/bin/k3d-install.sh

# Docker Hub pull-through cache shared by every exam cluster, so images are
# downloaded once instead of on every node of every exam. Best effort:
# env-setup only uses it when it is running.
if ! k3d registry list docker-io-mirror > /dev/null 2>&1; then
    k3d registry create docker-io-mirror --port 0.0.0.0:5000 --no-help \
        --proxy-remote-url https://registry-1.docker.io \
        -v docker-io-mirror:/var/lib/registry \
        || echo "$(date '+%Y-%m-%d %H:%M:%S') | [WARN] could not create the Docker Hub cache, pulling directly"
fi

# Bring back clusters that survived a container restart. k3d starts servers
# before agents, which etcd-profile clusters rely on (see env-setup).
for cluster in $(k3d cluster list --no-headers 2>/dev/null | awk '{print $1}'); do
    k3d cluster start "$cluster"
done

sleep 10
touch /ready

# Keep container running
tail -f /dev/null