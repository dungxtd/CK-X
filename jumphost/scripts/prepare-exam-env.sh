#!/bin/bash
exec >> /proc/1/fd/1 2>&1


# Log function with timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Usage: prepare-exam-env [--nodes N] [--exam-id ID] [--profile PROFILE]
NUMBER_OF_NODES=1
EXAM_ID=""
CLUSTER_PROFILE=default

while [ $# -gt 0 ]; do
  case "$1" in
    --nodes)   NUMBER_OF_NODES=$2; shift 2 ;;
    --exam-id) EXAM_ID=$2; shift 2 ;;
    --profile) CLUSTER_PROFILE=$2; shift 2 ;;
    *) log "ERROR: unknown argument: $1"; exit 1 ;;
  esac
done

echo "Exam ID: $EXAM_ID"
echo "Number of nodes: $NUMBER_OF_NODES"
echo "Cluster profile: $CLUSTER_PROFILE"

#check docker is running
if ! docker info > /dev/null 2>&1; then
  log "Docker is not running"
  log "Attempting to start docker"
  dockerd &
  sleep 5
  #check docker is running 3 times with 5 second interval
  for i in {1..3}; do
    if docker info > /dev/null 2>&1; then
      log "Docker started successfully"
      break
    fi
    log "Docker failed to start, retrying..."
    sleep 5
  done
fi

log "Starting exam environment preparation with $NUMBER_OF_NODES node(s)"

# Validate input
if ! [[ "$NUMBER_OF_NODES" =~ ^[0-9]+$ ]]; then
  log "ERROR: Number of nodes must be a positive integer"
  exit 1
fi
# The profile is forwarded through a remote shell, so only allow safe names
if ! [[ "$CLUSTER_PROFILE" =~ ^[a-z0-9-]+$ ]]; then
  log "ERROR: invalid cluster profile: $CLUSTER_PROFILE"
  exit 1
fi

# Setup kind cluster
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null candidate@k8s-api-server "env-setup --workers $NUMBER_OF_NODES --name $CLUSTER_NAME --profile $CLUSTER_PROFILE"

#Pull assets from URL
curl facilitator:3000/api/v1/exams/$EXAM_ID/assets -o assets.tar.gz

mkdir -p /tmp/exam-assets
#Unzip assets
tar -xzvf assets.tar.gz -C /tmp/exam-assets    

#Remove assets.tar.gz
rm assets.tar.gz

#make every file in /tmp/exam-assets executable
find /tmp/exam-assets -type f -exec chmod +x {} \;

echo "Exam assets downloaded and prepared successfully" 

export KUBECONFIG=/home/candidate/.kube/kubeconfig

sleep 5

#wait till api-server is ready
while ! kubectl get nodes > /dev/null 2>&1; do
  log "API server is not ready, retrying..."
  sleep 5
done

echo "API server is ready"

#Run setup scripts
for script in /tmp/exam-assets/scripts/setup/q*_setup.sh; do $script; done

log "Exam environment preparation completed successfully"
exit 0 