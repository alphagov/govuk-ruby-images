FROM --platform=$TARGETPLATFORM public.ecr.aws/lts/ubuntu:22.04_stable AS builder
ARG TARGETARCH

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Helper script for installing Debian packages.
COPY install_packages.sh /usr/sbin/install_packages

# Fail fast if mandatory build args are missing.
ARG RUBY_MAJOR RUBY_VERSION RUBY_CHECKSUM
RUN : "${RUBY_MAJOR?}" "${RUBY_VERSION?}"

# Environment variables required for build.
ENV LANG=C.UTF-8 \
    CPPFLAGS=-DENABLE_PATH_CHECK=0 \
    RUBY_MAJOR=${RUBY_MAJOR} \
    RUBY_VERSION=${RUBY_VERSION} \
    RUBY_CHECKSUM=${RUBY_CHECKSUM} 

# Build-time dependencies for Ruby.
# TODO: remove curl and gpg once downloads are done in the build script.
RUN install_packages curl ca-certificates g++ gpg libc-dev make bison patch libdb-dev libffi-dev libgdbm-dev libgmp-dev libreadline-dev libssl-dev libyaml-dev zlib1g-dev uuid-dev libjemalloc-dev

# Process the repo signing key for nodesource so we don't have to include gpg
# in the final image.
# TODO: do this externally, in the build script.
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /usr/share/keyrings/nodesource.gpg


# Build/install Ruby and update the default gems so that we have an up-to-date
# version of Bundler.
#
# TODO: figure out why `gem pristine` seems to be necessary in order to avoid
# errors like "Ignoring debug-1.4.0 because its extensions are not built." when
# running irb. Is something ending up in the wrong place during "Building
# native extensions" in make / make install?
WORKDIR /usr/src/ruby
RUN set -x; \
    MAKEFLAGS=-j"$(nproc)"; export MAKEFLAGS; \
    if [[ "$RUBY_VERSION" = "3.3.0" && "$TARGETARCH" = "arm64" ]]; then \
      : "workaround for https://bugs.ruby-lang.org/issues/20085"; \
      ASFLAGS="-mbranch-protection=pac-ret"; export ASFLAGS; \
    fi; \
    ruby_tarball="ruby-${RUBY_VERSION}.tar.gz"; \
    curl -fsSLO "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/${ruby_tarball}"; \
    echo "${RUBY_CHECKSUM} ${ruby_tarball}" | sha256sum --check --strict --status; \
    tar -xf "${ruby_tarball}" --strip-components=1; \
    arch="$(uname -m)-linux-gnu"; \
    ./configure \
      --build="${arch}" --host="${arch}" --target="${arch}" \
      --sysconfdir=/etc \
      --mandir=/tmp/throwaway \
      --disable-install-doc \
      --enable-shared \
    ; \
    make; \
    make install; \
    gem update --system --silent --no-document; \
    gem pristine --extensions; \
    gem cleanup;


FROM --platform=$TARGETPLATFORM public.ecr.aws/lts/ubuntu:22.04_stable

LABEL org.opencontainers.image.title="govuk-ruby-base"
LABEL org.opencontainers.image.authors="GOV.UK Platform Engineering"
LABEL org.opencontainers.image.description="Base Image for GOV.UK Ruby-based Apps"
LABEL org.opencontainers.image.source="https://github.com/alphagov/govuk-ruby-images"
LABEL org.opencontainers.image.vendor="GDS"

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]
ARG RUBY_MAJOR

COPY install_packages.sh /usr/sbin/install_packages
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/include/ /usr/local/include/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/share/ /usr/local/share/

# Environment variables common to most GOV.UK apps.
ENV APP_HOME=/app \
    GEM_HOME=/usr/local/bundle \
    GEM_PATH=/usr/local/lib/ruby/gems/$RUBY_MAJOR \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
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
# TODO: remove rds-combined-ca-bundle.pem once Router API is using global-bundle.pem.
ADD https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem /etc/ssl/certs/rds-combined-ca-bundle.pem
ADD https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-global-bundle.pem

# Wrap Ruby binaries in a script that sets up a TMPDIR that Ruby will accept.
# TODO: remove this when Ruby allows disabling its permissions checks on /tmp.
ARG ruby_bin=/usr/local/bin
ENV TMPDIR_FOR_RUBY_WRAPPERS_DIR=/usr/local/tmpdir_wrappers
WORKDIR $TMPDIR_FOR_RUBY_WRAPPERS_DIR
COPY with_tmpdir_for_ruby.sh ./with_tmpdir_for_ruby
RUN for wrapped_cmd in bundle puma pumactl rails rake "${ruby_bin}"/*; do \
        ln -f with_tmpdir_for_ruby "$(basename "${wrapped_cmd}")"; \
    done
# The wrappers come first in PATH so that commands like `rake` and `rails c`
# work as expected rather requiring everyone to prefix their commands with
# `with_tmpdir_for_ruby`.
ENV TMPDIR_FOR_RUBY_ORIGINAL_PATH=${PATH}
ENV PATH=${TMPDIR_FOR_RUBY_WRAPPERS_DIR}:${PATH}

# Install node.js, yarn and other runtime dependencies.
COPY --from=builder /usr/share/keyrings/nodesource.gpg /usr/share/keyrings/
RUN install_packages ca-certificates curl libjemalloc-dev libgdbm6 libyaml-0-2 \
      libmariadb3 libpq5 mariadb-client postgresql-client tzdata; \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x jammy main" | tee /etc/apt/sources.list.d/nodesource.list; \
    install_packages nodejs; \
    echo -n node version:\ ; node -v; \
    echo -n npm version:\ ; npm -v; \
    npm install -g yarn@1.22.19

# Use jemalloc by default.
ENV LD_PRELOAD=libjemalloc.so

# Crude smoke test of with_tmpdir_for_ruby.sh. Assert that Ruby Dir.tmpdir
# returns a subdirectory of /tmp.
RUN set -x; \
    expected=/tmp; \
    actual=$(ruby -e 'require "tmpdir"; d = Dir.tmpdir; Dir.rmdir(d); puts(File.dirname(d))'); \
    rm -fr /tmp/*; \
    [ "${expected}" = "${actual}" ]

WORKDIR $APP_HOME
# Some Rubygems (libraries) assume that they can write to tmp/ within the Rails
# app's base directory.
RUN ln -fs /tmp $APP_HOME
RUN groupadd -g 1001 app; \
    useradd -u 1001 -g app app --home $APP_HOME

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
