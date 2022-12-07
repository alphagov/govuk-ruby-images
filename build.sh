#!/bin/bash
#
# To build without pushing to a registry, set DRY_RUN to anything other than
# the empty string. For example:
#
#     DRY_RUN=1 ./build.sh
#
# To build and push images for just one Ruby version instead of all versions in
# versions/*, specify a version filename from versions/*. For example:
#
#     ./build.sh 3_1
#

set -eu

# Build (and push, unless $DRY_RUN is non-empty) the base and builder images
# for the Ruby version defined in the file versions/$1.
build_version() {
  RUBY_IS_PATCH=false
  # shellcheck disable=SC1090
  source "$1"

  for IMAGE_TYPE in base builder; do
    echo "Building ${IMAGE_TYPE} image for Ruby ${RUBY_MAJOR} (${RUBY_VERSION})"
    IMAGE_NAME="govuk-ruby-${IMAGE_TYPE}"
    docker build . \
      -t "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_MAJOR}" \
      -f "${IMAGE_TYPE}.Dockerfile" \
      --build-arg "RUBY_MAJOR=${RUBY_MAJOR}" \
      --build-arg "RUBY_VERSION=${RUBY_VERSION}"
    docker tag \
      "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_MAJOR}" \
      "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_VERSION}"

    if [[ -n ${DRY_RUN:-} ]]; then
      echo "dry run: not pushing image to registry"
    else
      if [[ "${RUBY_IS_PATCH}" != "true" ]]; then
        docker push "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_MAJOR}"
      fi
      docker push "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_VERSION}"
    fi
  done
}

if [[ -n "${1:-}" ]]; then
  build_version versions/"$1"
else
  for v in versions/*; do
    build_version "$v"
  done
fi
