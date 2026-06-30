#!/bin/dash

# This wrapper script is an attempt to work around Ruby's outdated assertion about /tmp permissions so we can keep the security
# benefit of readOnlyRootFileSystem
#
# We want to set readOnlyRootFileSystem as well as to read/write to /tmp. To enable this we mount an
# emptyDir volume on /tmp with read/write permissions. However Ruby is fussy about the permission bits on the /tmp directory
# (see https://github.com/ruby/ruby/blob/v2_7_6/lib/tmpdir.rb#L27).
#
# Since it is difficult to work around the check whilst keeping the emptyDir read/write permissions on /tmp we
# create a subdirectory inside $TMPDIR (or /tmp if not set) and run a command with TMPDIR set to the new subdirectory.
#
# This script can be invoked in two ways:
#
# 1) as "with_tmpdir_for_ruby", in which case the first positional argument is
# the command to run and the rest of the arguments are passed through to that
# command, or:
#
# 2) as the name of the command to run, in which case all positional arguments
# are passed through.
#

set -eu

usage() {
  echo "Usage:
    original_command [args ...]
    with_tmpdir_for_ruby original_command [args ...]" >&2
  exit 64  # EX_USAGE
}

if [ -n "${TMPDIR_FOR_RUBY:-}" ]; then
  echo "ERROR: with_tmpdir_for_ruby: TMPDIR_FOR_RUBY already set; aborting to avoid infinite loop (PATH=${PATH})" >&2
  exit 1
fi

invoked_as="$(basename "${0%.sh}")"
if [ "${invoked_as}" = "with_tmpdir_for_ruby" ]; then
  [ $# -eq 0 ] && usage
  cmd=$1
  shift
else
  cmd=$0
fi
cmd=$(basename "${cmd}")

PATH=$TMPDIR_FOR_RUBY_ORIGINAL_PATH
TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/ruby-app-XXXXXXXX")"
TMPDIR_FOR_RUBY=$TMPDIR
export PATH TMPDIR TMPDIR_FOR_RUBY
echo "INFO: with_tmpdir_for_ruby: execing ${cmd} with TMPDIR=${TMPDIR}" >&2
exec "${cmd}" "$@"
