ARG RUBY_MAJOR
FROM ghcr.io/alphagov/govuk-ruby-base:${RUBY_MAJOR}

RUN install_packages git

# Environment variables to make build cleaner and faster
ENV BUNDLE_IGNORE_MESSAGES=1 \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_JOBS=12 \
  MAKEFLAGS="-j12"

# Make bundle not install documentation files
RUN echo 'install: --no-document' >> /etc/gemrc

LABEL org.opencontainers.image.source=https://github.com/alphagov/govuk-ruby-images
