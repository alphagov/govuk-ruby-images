#!/bin/sh
#
# Create a subdirectory inside $TMPDIR (or /tmp if not set) and run the given
# command with TMPDIR set to the new subdirectory.
#
# The purpose of this is to work around a check in the Ruby standard library
# which is inappropriate for running on Kubernetes in a read-only root
# filesystem with an ephemeral volume mounted read-write on /tmp:
# https://github.com/ruby/ruby/blob/v2_7_6/lib/tmpdir.rb#L27
#
# Basically, Ruby is overly fussy about the mode bits on the temp directory in
# a way that's difficult to work around neatly in Kubernetes. The intent is
# clearly to mitigate potential tempfile vulnerabilities on multiuser servers,
# but this is a non-issue in a container-per-process model.
#
# Usage: with_tmpdir_for_ruby command [args ...]
#

set -eux

dir=$(mktemp -d "${TMPDIR:-/tmp}/ruby-app-XXXXXXXX")
TMPDIR="${dir}" "$@"
