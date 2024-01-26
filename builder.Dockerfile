ARG OWNER=alphagov
ARG RUBY_MAJOR RUBY_CHECKSUM
FROM --platform=$TARGETPLATFORM ghcr.io/${OWNER}/govuk-ruby-base:${RUBY_MAJOR}

RUN install_packages \
    g++ git gpg libc-dev libcurl4-openssl-dev libgdbm-dev libssl-dev \
    libmariadb-dev-compat libpq-dev libyaml-dev make xz-utils

# Environment variables to make build cleaner and faster
ENV BUNDLE_IGNORE_MESSAGES=1 \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_JOBS=12 \
    MAKEFLAGS="-j12"
RUN echo 'gem: --no-document' >> /etc/gemrc

ENV SECRET_KEY_BASE_DUMMY=1

LABEL org.opencontainers.image.title="govuk-ruby-builder"
LABEL org.opencontainers.image.authors="GOV.UK Platform Engineering"
LABEL org.opencontainers.image.description="Builder Image for GOV.UK Ruby-based Apps"
LABEL org.opencontainers.image.source=https://github.com/${OWNER}/govuk-ruby-images
LABEL org.opencontainers.image.vendor="GDS"
