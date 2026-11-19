#!/bin/bash
#
# Print a key identifying the package versions that apt would install today in
# the given (published) image. The build passes it to base.Dockerfile as
# APT_REFRESH_KEY so that the apt layer is rebuilt only when Ubuntu or
# NodeSource have published an update, instead of being reused from the build
# cache indefinitely.
#
# Pending updates are listed on stderr for the build log.
#
# If the image can't be inspected (for example a new Ruby version that hasn't
# been published yet, or a registry error), prints a unique key so that the
# build refreshes the apt layer rather than reusing a possibly stale one.

set -euo pipefail

image=${1:?usage: $0 <image>}

# Runs inside the image. Prints "<package> <installed> <candidate>" per package.
# shellcheck disable=SC2016  # expanded inside the container, not here
probe='set -euo pipefail
apt-get update -qq >/dev/null
dpkg-query -W -f "\${binary:Package}\n" | xargs apt-cache policy |
  awk "/^[^ ]/ {p=\$1; sub(/:\$/, \"\", p)} /Installed:/ {i=\$2} /Candidate:/ {print p, i, \$2}" |
  sort'

if versions=$(docker run --rm --pull always --entrypoint bash "${image}" -c "${probe}") &&
    [ -n "${versions}" ]; then
  pending=$(awk '$2 != $3 {print "  " $1 ": " $2 " -> " $3}' <<<"${versions}")
  echo "Pending updates in ${image}:" >&2
  echo "${pending:-  none}" >&2
  awk '{print $1, $3}' <<<"${versions}" | sha256sum | cut -c1-16
else
  echo "Could not inspect ${image}; forcing a fresh apt layer." >&2
  echo "fresh-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM}"
fi
