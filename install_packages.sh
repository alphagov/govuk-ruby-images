#!/bin/bash
# Script for installing packages and removing apt cache
#
# Set APT_UPGRADE=1 to also upgrade already-installed packages.

set -eux
export DEBIAN_FRONTEND=noninteractive
n=0
max=2
until [ $n -gt $max ]; do
    set +e
    (
      apt-get update -qq &&
      if [ "${APT_UPGRADE:-}" = "1" ]; then apt-get upgrade -y --no-install-recommends; fi &&
      apt-get install -y --no-install-recommends "$@"
    )
    CODE=$?
    set -e
    if [ $CODE -eq 0 ]; then
        break
    fi
    if [ $n -eq $max ]; then
        exit $CODE
    fi
    echo "apt failed, retrying"
    n=$((n + 1))
done
rm -r /var/lib/apt/lists /var/cache/apt/archives
