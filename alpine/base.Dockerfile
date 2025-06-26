# make Node Binaries from Node.js Alpine Image
ARG NODE_VERSION=24.3.0
ARG ALPINE_VERSION=3.22.0

FROM node:${NODE_VERSION}-alpine AS nodejs

FROM alpine:${ALPINE_VERSION}

FROM public.ecr.aws/docker/library/alpine:3.22 AS abuild
SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

ARG RUBY_MAJOR=3.4 RUBY_VERSION=3.4.4

ENV HISTFILE=/dev/null

RUN apk --no-cache add alpine-sdk coreutils cmake sudo \
  && adduser -G abuild -g "Alpine Package Builder" -s /bin/ash -D builder \
  && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && mkdir /packages \
  && chown builder:abuild /packages \
  && mkdir -p /var/cache/apk \
  && ln -s /var/cache/apk /etc/apk/cache

# Build Ruby from Source
FROM abuild AS rubybuild
SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    CPPFLAGS=-DENABLE_PATH_CHECK=0 \
    HISTFILE=/dev/null \
    RUBY_VERSION=$RUBY_VERSION

COPY --chown=builder:abuild /ruby /home/builder/package/ruby
RUN apk update \
    && chmod 755 /home/builder/package/ruby \
    && chmod 644 /home/builder/package/ruby/*.patch

USER builder
WORKDIR /home/builder/package
RUN abuild-keygen -a -i -n
RUN cd /home/builder/package/ruby \
    && abuild checksum \
    && abuild -r
RUN ls -al /home/builder/packages/package/aarch64
RUN sudo apk add --no-cache /home/builder/packages/package/aarch64/ruby-${RUBY_VERSION}-r0.apk \
    && ruby -v

# Install Ruby Build from Previous Stage
FROM public.ecr.aws/docker/library/alpine:3.22 AS rubyinstall

ARG RUBY_MAJOR=3.4 RUBY_VERSION=3.4.4

LABEL org.opencontainers.image.title="govuk-ruby-base-alpine"
LABEL org.opencontainers.image.authors="GOV.UK Platform Engineering"
LABEL org.opencontainers.image.description="Base image for GOV.UK Ruby apps based on Alpine Linux"
LABEL org.opencontainers.image.source="https://github.com/alphagov/govuk-ruby-images"
LABEL org.opencontainers.image.vendor="GDS"

SHELL ["/bin/ash", "-euo", "pipefail", "-c"]

ENV LANG=C.UTF-8 \
    CPPFLAGS=-DENABLE_PATH_CHECK=0 \
    HISTFILE=/dev/null \
    RUBY_VERSION=$RUBY_VERSION

# Pull Node.js Binaries from Previous Stage
COPY --from=nodejs /usr/lib /usr/lib
COPY --from=nodejs /usr/local/lib /usr/local/lib
COPY --from=nodejs /usr/local/include /usr/local/include
COPY --from=nodejs /usr/local/bin /usr/local/bin

COPY --from=rubybuild /etc/apk/keys /etc/apk/keys
COPY --from=rubybuild /home/builder/packages/package/aarch64/ruby-*.apk /tmp/packages/ruby/

ENV APP_HOME=/app \
    GEM_HOME=/usr/local/bundle \
    GEM_PATH=/usr/local/lib/ruby/gems/$RUBY_MAJOR \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    HISTFILE=/dev/null  \
    LD_PRELOAD=/usr/lib/libjemalloc.so.2 \
    PATH=/usr/local/bundle/bin:$PATH \
    IRBRC=/etc/irb.rc \
    XDG_DATA_HOME=/tmp \
    RACK_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development test cucumber" \
    BOOTSNAP_CACHE_DIR=/var/cache \
    GOVUK_APP_DOMAIN=www.gov.uk \
    GOVUK_WEBSITE_ROOT=https://www.gov.uk \
    GOVUK_PROMETHEUS_EXPORTER=true \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/London

# Amazon RDS cert bundle for connecting to managed databases over TLS.
ADD https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-global-bundle.pem

RUN apk add --no-cache jemalloc-dev /tmp/packages/ruby/ruby-$RUBY_VERSION-r0.apk \
    && rm -rf /tmp/packages/ruby \
    && ruby -v \
    && gem update --system --silent --no-document \
    && gem install rdoc --no-document \
    && gem pristine --extensions \
    && gem cleanup \
    && bundle --version

# Wrap Ruby binaries in a script that sets up a TMPDIR that Ruby will accept.
# TODO: remove this when Ruby allows disabling its permissions checks on /tmp.
ARG ruby_bin=/usr/local/bin
ENV TMPDIR_FOR_RUBY_WRAPPERS_DIR=/usr/local/tmpdir_wrappers
WORKDIR $TMPDIR_FOR_RUBY_WRAPPERS_DIR
COPY /with_tmpdir_for_ruby.sh ./with_tmpdir_for_ruby
RUN for wrapped_cmd in bundle puma pumactl rails rake "${ruby_bin}"/*; do \
        ln -f with_tmpdir_for_ruby "$(basename "${wrapped_cmd}")"; \
    done
# The wrappers come first in PATH so that commands like `rake` and `rails c`
# work as expected rather requiring everyone to prefix their commands with
# `with_tmpdir_for_ruby`.
ENV TMPDIR_FOR_RUBY_ORIGINAL_PATH=${PATH}
ENV PATH=${TMPDIR_FOR_RUBY_WRAPPERS_DIR}:${PATH}

RUN apk add --no-cache curl gdbm jsonnet-libs yaml-dev mariadb-dev libpq \
        mariadb-client postgresql-client tzdata \
    && npm install -g yarn@1.22.22 --force \
    && rm -rf /var/cache/apk/*

# Crude smoke test of with_tmpdir_for_ruby.sh. Assert that Ruby Dir.tmpdir
# returns /tmp or a subdirectory of /tmp.
RUN set -x; \
    actual=$(ruby -e 'require "tmpdir"; puts Dir.tmpdir'); \
    case "$actual" in \
      /tmp|/tmp/*) ;; \
      *) echo "Dir.tmpdir is not under /tmp: $actual" >&2; exit 1 ;; \
    esac

WORKDIR $APP_HOME
# Some Rubygems (libraries) assume that they can write to tmp/ within the Rails
# app's base directory.
RUN ln -fs /tmp $APP_HOME
RUN addgroup -g 1001 app && \
    adduser -D -u 1001 -G app -h $APP_HOME app

# Set irb's history path to somewhere writable so that it doesn't complain.
RUN echo 'IRB.conf[:HISTORY_FILE] = "/tmp/irb_history"' > "$IRBRC"

# Crude smoke test: assert that each of the main binaries exits cleanly and
# that the openssl gem loads.
RUN set -x; \
    ruby --version; \
    echo RUBY_DESCRIPTION | irb; \
    echo 'puts OpenSSL::OPENSSL_VERSION' | ruby -r openssl; \
    gem env; \
    bundle version; \
    rm -r /tmp/*;