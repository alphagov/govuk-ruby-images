#!/bin/bash
#
# This script is just for building locally. The production build is in
# .github/workflows.
#

set -eu

usage() {
  echo >&2 "usage: $0 <major.minor.patch Ruby version to build e.g. 3.3.0>"
  echo >&2 "To push after build, set PUSH_TO_REGISTRY=1 and a valid GITHUB_TOKEN."
  exit 64
}

sha_for_version() {
  jq -r <build-matrix.json \
    '.version[] | select(.rubyver|join(".") == "'"$1"'") | .checksum'
}

major_minor_version() {
  jq -r <build-matrix.json \
    '.version[] | select(.rubyver|join(".") == "'"$1"'") | .rubyver[0:2]|join(".")'
}

build_version() {
  ruby_version=$1
  ruby_major_minor=$(major_minor_version "${ruby_version}")

  for img in base builder; do
    echo "Building ${img} image for Ruby ${ruby_major_minor} (${ruby_version})"
    image_name="govuk-ruby-${img}"
    docker buildx build \
      --platform "${ARCHS:-linux/amd64,linux/arm64}" \
      --load \
      --build-arg "RUBY_MAJOR=${ruby_major_minor}" \
      --build-arg "RUBY_VERSION=${ruby_version}" \
      --build-arg "RUBY_CHECKSUM=$(sha_for_version "$ruby_version")" \
      -t "ghcr.io/alphagov/${image_name}:${ruby_major_minor}" \
      -f "${img}.Dockerfile" .

    if [[ ${PUSH_TO_REGISTRY:-} = "1" ]]; then
      echo "pushing to registry"
      docker push "ghcr.io/alphagov/${image_name}:${ruby_major_minor}"
    fi
  done
}

[[ -n "${1:-}" ]] || usage
build_version "$1"
