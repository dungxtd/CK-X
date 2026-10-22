#!/bin/sh

# ===============================================================================
#   Exam cluster host entrypoint
#   Purpose: start dockerd, the registry caches and any existing kind clusters
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

#add user for ssh access
adduser -S -D -H -s /sbin/nologin -G sshd sshd

#start ssh service
/usr/sbin/sshd -D &

# kind attaches every cluster to this network; create it up front so the
# registry caches can join it before the first cluster exists
docker network inspect kind > /dev/null 2>&1 || docker network create kind

# Pull-through caches shared by every exam cluster, so images are downloaded
# once instead of on every node of every exam (one registry per upstream,
# mapped in /usr/local/share/ckx/certs.d). Best effort: containerd pulls
# from upstream when a cache is down.
while read -r name upstream; do
    docker container inspect "$name" > /dev/null 2>&1 && continue
    docker run -d --name "$name" --restart=always --network kind \
        -e "REGISTRY_PROXY_REMOTEURL=$upstream" -v "$name:/var/lib/registry" registry:2 > /dev/null \
        || echo "$(date '+%Y-%m-%d %H:%M:%S') | [WARN] could not start $name, pulling $upstream directly"
done <<EOF
docker-io-mirror https://registry-1.docker.io
registry-k8s-io-mirror https://registry.k8s.io
ghcr-io-mirror https://ghcr.io
quay-io-mirror https://quay.io
EOF

# Exam node image (kind node + sshd), built once and kept on the volume
if ! docker image inspect "$CKX_NODE_IMAGE" > /dev/null 2>&1; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') | [INFO] Building $CKX_NODE_IMAGE"
    docker build -q -t "$CKX_NODE_IMAGE" --build-arg "BASE=$KIND_NODE_IMAGE" /usr/local/share/ckx/node
fi

# Bring back clusters that survived a container restart: control planes
# first, then workers (kind re-points nodes at their new IPs on boot)
for role in control-plane worker; do
    nodes=$(docker ps -aq --filter label=io.x-k8s.kind.role=$role)
    [ -n "$nodes" ] && docker start $nodes > /dev/null
done

sleep 10
touch /ready

# Keep container running
tail -f /dev/null