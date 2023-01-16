FROM public.ecr.aws/lts/ubuntu:22.04_stable AS builder
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Helper script for installing Debian packages.
COPY install_packages.sh /usr/sbin/install_packages

# Fail fast if mandatory build args are missing.
ARG RUBY_MAJOR RUBY_VERSION
RUN : "${RUBY_MAJOR?}" "${RUBY_VERSION?}"

# Environment variables required for build.
ENV LANG=C.UTF-8 \
    CPPFLAGS=-DENABLE_PATH_CHECK=0 \
    OPENSSL_VERSION=1.1.1s \
    RUBY_MAJOR=${RUBY_MAJOR} \
    RUBY_VERSION=${RUBY_VERSION}

# Build-time dependencies.
# TODO: remove perl once we no longer need to build OpenSSL.
RUN install_packages curl ca-certificates g++ gpg libc-dev make bison libgdbm-dev zlib1g-dev libreadline-dev libjemalloc-dev perl

# Process the repo signing key for nodesource so we don't have to include gpg
# in the final image.
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor > /usr/share/keyrings/nodesource.gpg

COPY SHA256SUMS /

# TODO: stop building OpenSSL once all apps are on Ruby 3.1+.
WORKDIR /usr/src/openssl
RUN set -x; \
    export MAKEFLAGS=-j"$(nproc)"; \
    openssl_tarball="openssl-${OPENSSL_VERSION}.tar.gz"; \
    curl -fsSLO "https://www.openssl.org/source/${openssl_tarball}"; \
    grep "${openssl_tarball}" /SHA256SUMS | sha256sum --check --strict; \
    tar -xf "${openssl_tarball}" --strip-components=1; \
    ./config --prefix=/opt/openssl --openssldir=/opt/openssl no-tests shared zlib; \
    make; \
    make install_sw;  # Avoid building manpages and such.

# Build/install Ruby and update the default gems so that we have an up-to-date
# version of Bundler.
#
# TODO: figure out why `gem pristine` seems to be necessary in order to avoid
# errors like "Ignoring debug-1.4.0 because its extensions are not built." when
# running irb. Is something ending up in the wrong place during "Building
# native extensions" in make / make install?
WORKDIR /usr/src/ruby
RUN set -x; \
    export MAKEFLAGS=-j"$(nproc)"; \
    ruby_tarball="ruby-${RUBY_VERSION}.tar.gz"; \
    curl -fsSLO "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/${ruby_tarball}"; \
    grep "${ruby_tarball}" /SHA256SUMS | sha256sum --check --strict; \
    tar -xf "${ruby_tarball}" --strip-components=1; \
    arch="$(uname -m)-linux-gnu"; \
    ./configure \
      --build="${arch}" --host="${arch}" --target="${arch}" \
      --sysconfdir=/etc \
      --mandir=/tmp/throwaway \
      --disable-install-doc \
      --enable-shared \
      --with-jemalloc \
      --with-openssl-dir=/opt/openssl \
    make; \
    make install; \
    gem update --system --silent --no-document; \
    gem pristine --extensions; \
    gem cleanup;


FROM public.ecr.aws/lts/ubuntu:22.04_stable
SHELL ["/bin/bash", "-uo", "pipefail", "-c"]
ARG RUBY_MAJOR

COPY install_packages.sh /usr/sbin/install_packages
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/include/ /usr/local/include/
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/share/ /usr/local/share/
COPY --from=builder /opt/openssl /opt/openssl
# Make our locally-built OpenSSL use the system cacert store.
RUN rmdir /opt/openssl/certs; \
    ln -s /etc/ssl/certs /opt/openssl/certs

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
RUN install_packages ca-certificates curl libjemalloc-dev libmariadb3 libpq5 tzdata && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x jammy main" | tee /etc/apt/sources.list.d/nodesource.list && \
    install_packages nodejs && npm install -g yarn

# Crude smoke test of with_tmpdir_for_ruby.sh. Assert that Ruby Dir.tmpdir
# returns a subdirectory of /tmp.
RUN set -x; \
    expected=/tmp; \
    actual=$(ruby -e 'require "tmpdir"; d = Dir.tmpdir; Dir.rmdir(d); puts(File.dirname(d))'); \
    [ "${expected}" = "${actual}" ]

WORKDIR $APP_HOME
# Some Rubygems (libraries) assume that they can write to tmp/ within the Rails
# app's base directory.
RUN ln -fs /tmp $APP_HOME
RUN groupadd -g 1001 app && \
    useradd -u 1001 -g app app --home $APP_HOME

# Set irb's history path to somewhere writable so that it doesn't complain.
RUN echo 'IRB.conf[:HISTORY_FILE] = "/tmp/irb_history"' > "$IRBRC"

# Crude smoke test: assert that each of the main binaries exits cleanly.
RUN set -x; \
    ruby --version; \
    echo RUBY_DESCRIPTION | irb; \
    gem env; \
    bundle version; \
    rm -r /tmp/*;

LABEL org.opencontainers.image.source=https://github.com/alphagov/govuk-ruby-images
