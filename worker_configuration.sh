#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# This script assumes that the 'join_command.sh' file, generated on the master node,
# has been copied to this worker node's /home/ubuntu/ directory.
# You can copy it using scp from the master node:
# scp /home/ubuntu/join_command.sh ubuntu@<worker_ip>:/home/ubuntu/

if [ ! -f "/home/ubuntu/join_command.sh" ]; then
    echo "Error: /home/ubuntu/join_command.sh not found. Please copy it from the master node."
    exit 1
fi

echo "Joining worker node to Kubernetes cluster..."
sudo /home/ubuntu/join_command.sh --ignore-preflight-errors=all

echo "Worker node configuration script completed."


