ARG OWNER=alphagov
ARG BASE_IMAGE_DIGEST
FROM --platform=$TARGETPLATFORM ghcr.io/${OWNER}/govuk-ruby-base@${BASE_IMAGE_DIGEST}

RUN install_packages \
    g++ git gpg libc-dev libcurl4-openssl-dev libgdbm-dev libssl-dev \
    libmariadb-dev-compat libpq-dev libjsonnet-dev libyaml-dev make xz-utils

# Environment variables to make build cleaner and faster
ENV BUNDLE_IGNORE_MESSAGES=1 \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_JOBS=12 \
    MAKEFLAGS="-j12"
RUN echo 'gem: --no-document' >> /etc/gemrc

ENV SECRET_KEY_BASE_DUMMY=1

ENV GOVUK_ENVIRONMENT="development"

COPY govuk_prompt.sh /etc/govuk_prompt.sh
RUN chmod +x /etc/govuk_prompt.sh \
    && echo '[ -f /etc/govuk_prompt.sh ] && . /etc/govuk_prompt.sh' >> /etc/bash.bashrc

ENV BASH_ENV="/etc/govuk_prompt.sh"

LABEL org.opencontainers.image.title="govuk-ruby-builder"
LABEL org.opencontainers.image.authors="GOV.UK Platform Engineering"
LABEL org.opencontainers.image.description="Builder image for GOV.UK Ruby apps"
LABEL org.opencontainers.image.source=https://github.com/${OWNER}/govuk-ruby-images
LABEL org.opencontainers.image.vendor="GDS"
