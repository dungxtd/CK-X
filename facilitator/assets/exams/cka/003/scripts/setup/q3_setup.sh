#!/bin/bash
set -e

# The real etcd cluster (Part A infra change) and client certs at
# /home/candidate/.kube/etcd-certs already exist cluster-wide, nothing to provision here.
mkdir -p /tmp/exam

echo "Setup completed for Question 3"
