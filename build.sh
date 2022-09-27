#!/bin/bash
#
# To run without pushing to DockerHub, set DRY_RUN to anything other than the
# empty string. For example:
#
#     DRY_RUN=1 ./build.sh
#

set -eu

for VERSION in versions/*; do
  RUBY_IS_PATCH=false
  source "${VERSION}"

  for IMAGE_TYPE in base builder; do
    echo "Building ${IMAGE_TYPE} image for Ruby ${RUBY_MAJOR} (${RUBY_VERSION})"
    IMAGE_NAME="govuk-ruby-${IMAGE_TYPE}"
    docker build . \
      -t "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_MAJOR}" \
      -f "${IMAGE_TYPE}.Dockerfile" \
      --build-arg "RUBY_MAJOR=${RUBY_MAJOR}" \
      --build-arg "RUBY_VERSION=${RUBY_VERSION}" \
      --build-arg "RUBY_DOWNLOAD_SHA256=${RUBY_DOWNLOAD_SHA256}"
    docker tag \
      "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_MAJOR}" \
      "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_VERSION}"

    if [[ -n ${DRY_RUN:-} ]]; then
      echo "DRY_RUN is set so not pushing to DockerHub"
    else
      if [[ "${RUBY_IS_PATCH}" != "true" ]]; then
        docker push "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_MAJOR}"
      fi
      docker push "ghcr.io/alphagov/${IMAGE_NAME}:${RUBY_VERSION}"
    fi
  done
done
