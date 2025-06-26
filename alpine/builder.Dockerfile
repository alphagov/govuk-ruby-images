# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

# FROM ghcr.io/${OWNER}/govuk-ruby-base-alpine@${BASE_IMAGE_DIGEST}
FROM govuk-ruby-base-alpine:latest

ARG OWNER=alphagov

RUN apk add --no-cache \
    g++ git gnupg libc-dev libcurl gdbm openssl-dev \
    mariadb-connector-c-dev postgresql-dev jsonnet-dev yaml-dev make xz

# Environment variables to make build cleaner and faster
ENV BUNDLE_IGNORE_MESSAGES=1 \
    BUNDLE_SILENCE_ROOT_WARNING=1 \
    BUNDLE_JOBS=12 \
    OWNER=$OWNER \
    MAKEFLAGS="-j12"
RUN echo 'gem: --no-document' >> /etc/gemrc

ENV SECRET_KEY_BASE_DUMMY=1

LABEL org.opencontainers.image.title="govuk-ruby-builder-alpine"
LABEL org.opencontainers.image.authors="GOV.UK Platform Engineering"
LABEL org.opencontainers.image.description="Builder image for GOV.UK Ruby apps"
LABEL org.opencontainers.image.source=https://github.com/{$OWNER}/govuk-ruby-images
LABEL org.opencontainers.image.vendor="GDS"