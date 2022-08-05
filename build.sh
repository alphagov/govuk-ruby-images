#!/bin/bash

for VERSION in versions/*; do
  RUBY_IS_PATCH=false
  source $VERSION
  echo "Building image for Ruby ${RUBY_MAJOR} (${RUBY_VERSION})"
  # Build & push base image
  docker build . -t "ghcr.io/alphagov/govuk-ruby-base:${RUBY_MAJOR}" \
    -f base.Dockerfile \
    --build-arg "RUBY_MAJOR=${RUBY_MAJOR}" \
    --build-arg "RUBY_VERSION=${RUBY_VERSION}" \
    --build-arg "RUBY_DOWNLOAD_SHA256=${RUBY_DOWNLOAD_SHA256}"
  docker tag "ghcr.io/alphagov/govuk-ruby-base:${RUBY_MAJOR}" "ghcr.io/alphagov/govuk-ruby-base:${RUBY_VERSION}"
  if [ "${RUBY_IS_PATCH}" != "true" ]; then
    docker push "ghcr.io/alphagov/govuk-ruby-base:${RUBY_MAJOR}"
  fi
  docker push "ghcr.io/alphagov/govuk-ruby-base:${RUBY_VERSION}"

  # Build & push builder image
  docker build . -t "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_MAJOR}" \
    -f builder.Dockerfile \
    --build-arg "RUBY_MAJOR=${RUBY_MAJOR}"
  docker tag "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_MAJOR}" "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_VERSION}"
  if [ "${RUBY_IS_PATCH}" != "true" ]; then
    docker push "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_MAJOR}"
  fi
  docker push "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_VERSION}"
done