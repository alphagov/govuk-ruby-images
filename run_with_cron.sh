#!/bin/bash

# Start cron (forks on start)
cron

# Create file for cron environment
touch /etc/cron-environment
chown app:app /etc/cron-environment
chmod 755 /etc/cron-environment

# Dump environment to file and start app as unprivileged user
CMDARGS="$@"
sudo -E -u app /bin/bash -c "cd /app && (env | grep -v LS_COLORS | sed 's/^/export /' > /etc/cron-environment) && ${CMDARGS}"
