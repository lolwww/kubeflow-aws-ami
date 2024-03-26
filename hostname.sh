#!/bin/bash
HOSTNAME="kubeflow-appliance"

# Get the current system hostname
CURRENT_HOSTNAME=$(hostnamectl --static)

# Check if the current hostname is the same as the hardcoded hostname
if [ "$CURRENT_HOSTNAME" != "$HOSTNAME" ]; then
	# The hostnames do not match, set the new hostname
	echo "Setting new hostname to '$HOSTNAME'"
	hostnamectl set-hostname "$HOSTNAME"

	# Wait for cloud-init to finish its setup
	echo "Waiting for cloud-init to complete..."
	cloud-init status --wait

	sleep 10
	reboot
else
	echo "The current hostname matches. No changes made."
fi

