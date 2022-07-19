#!/bin/bash

for VERSION in versions/*; do
  source $VERSION
  echo "Building image for Ruby ${RUBY_MAJOR} (${RUBY_VERSION})"
  docker build . -t "ghcr.io/alphagov/govuk-ruby-base:${RUBY_MAJOR}" \
    -f base.Dockerfile \
    --build-arg "RUBY_MAJOR=${RUBY_MAJOR}" \
    --build-arg "RUBY_VERSION=${RUBY_VERSION}" \
    --build-arg "RUBY_DOWNLOAD_SHA256=${RUBY_DOWNLOAD_SHA256}"
  docker push "ghcr.io/alphagov/govuk-ruby-base:${RUBY_MAJOR}"

  docker build . -t "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_MAJOR}" \
    -f builder.Dockerfile \
    --build-arg "RUBY_MAJOR=${RUBY_MAJOR}"
  docker push "ghcr.io/alphagov/govuk-ruby-builder:${RUBY_MAJOR}"
done