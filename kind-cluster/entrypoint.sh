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

# Pull-through caches shared by every exam cluster, so images are downloaded
# once instead of on every node of every exam (one registry per upstream,
# mirrors mapped in /usr/local/share/k3d-registries.yaml). Best effort:
# env-setup only uses the ones that are running.
while read -r name port upstream; do
    k3d registry list "$name" > /dev/null 2>&1 && continue
    k3d registry create "$name" --port "0.0.0.0:$port" --no-help \
        --proxy-remote-url "$upstream" -v "$name:/var/lib/registry" \
        || echo "$(date '+%Y-%m-%d %H:%M:%S') | [WARN] could not create $name, pulling $upstream directly"
done <<EOF
docker-io-mirror 5000 https://registry-1.docker.io
registry-k8s-io-mirror 5001 https://registry.k8s.io
ghcr-io-mirror 5002 https://ghcr.io
quay-io-mirror 5003 https://quay.io
EOF

# Bring back clusters that survived a container restart. k3d starts servers
# before agents, which etcd-profile clusters rely on (see env-setup).
for cluster in $(k3d cluster list --no-headers 2>/dev/null | awk '{print $1}'); do
    k3d cluster start "$cluster"
done

sleep 10
touch /ready

# Keep container running
tail -f /dev/null