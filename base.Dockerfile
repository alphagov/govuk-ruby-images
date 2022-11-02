FROM public.ecr.aws/lts/ubuntu:22.04_stable AS builder
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy helper script for package installation
COPY install_packages.sh /usr/sbin/install_packages
RUN chmod 755 /usr/sbin/install_packages

# Fail fast if mandatory build args are missing.
ARG RUBY_MAJOR RUBY_VERSION RUBY_DOWNLOAD_SHA256
RUN : "${RUBY_MAJOR?}" "${RUBY_VERSION?}" "${RUBY_DOWNLOAD_SHA256?}"

# Set environment variables required for build
ENV LANG=C.UTF-8 \
    RUBY_MAJOR=${RUBY_MAJOR} \
    RUBY_VERSION=${RUBY_VERSION} \
    RUBY_DOWNLOAD_SHA256=${RUBY_DOWNLOAD_SHA256} \
    MAKEFLAGS=-j"$(nproc)"

# Install build dependencies
RUN install_packages build-essential bison dpkg-dev libgdbm-dev ruby wget autoconf zlib1g-dev libreadline-dev checkinstall

# TODO: stop building OpenSSL once all apps are on Ruby 3.1+.
RUN set -eux; \
    wget -O openssl.tar.gz "https://www.openssl.org/source/openssl-1.1.1s.tar.gz"; \
    echo "c5ac01e760ee6ff0dab61d6b2bbd30146724d063eb322180c6f18a6f74e4b6aa openssl.tar.gz" | sha256sum --check; \
    mkdir -p /usr/src/openssl; \
    tar -xf openssl.tar.gz -C /usr/src/openssl --strip-components=1; \
    cd /usr/src/openssl; \
    ./config --prefix=/opt/openssl --openssldir=/opt/openssl shared zlib; \
    make; \
    make install_sw;  # Avoid building manpages and such.

# Build Ruby
RUN set -eux; \
    \
    wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR}/ruby-${RUBY_VERSION}.tar.xz"; \
    echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum --check --strict; \
    \
    mkdir -p /usr/src/ruby /build; \
    tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1; \
    rm ruby.tar.xz; \
    \
    cd /usr/src/ruby; \
    \
    { \
      echo '#define ENABLE_PATH_CHECK 0'; \
      echo; \
      cat file.c; \
    } > file.c.new; \
    mv file.c.new file.c; \
    \
    autoconf; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
      --build="$gnuArch" \
      --disable-install-doc \
      --enable-shared \
      --with-destdir=/build \
      --with-openssl-dir=/opt/openssl \
    ; \
    make -j "$(nproc)"; \
    make install;


FROM public.ecr.aws/lts/ubuntu:22.04_stable

# Copy helper script for package installation
COPY --from=builder /usr/sbin/install_packages /usr/sbin/install_packages

# Copy Ruby binaries from builder image
COPY --from=builder /build /

# Copy OpenSSL and link in system castore
COPY --from=builder /opt/openssl /opt/openssl
RUN rmdir /opt/openssl/certs; \
    ln -s /etc/ssl/certs /opt/openssl/certs

# Set common environment variables
ENV APP_HOME=/app \
    GEM_HOME=/usr/local/bundle \
    BUNDLE_APP_CONFIG=/usr/local/bundle \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_BIN=/usr/local/bundle/bin \
    PATH=/usr/local/bundle/bin:$PATH \
    IRBRC=/etc/irb.rc \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_WITHOUT="development test cucumber" \
    BOOTSNAP_CACHE_DIR=/var/cache/bootsnap \
    GOVUK_APP_DOMAIN=www.gov.uk \
    GOVUK_WEBSITE_ROOT=https://www.gov.uk \
    GOVUK_PROMETHEUS_EXPORTER=true \
    DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/London

# Install node.js, yarn and other runtime dependencies
RUN install_packages ca-certificates curl gpg default-libmysqlclient-dev tzdata libpq5 cron && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee "/usr/share/keyrings/nodesource.gpg" >/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x jammy main" | tee /etc/apt/sources.list.d/nodesource.list && \
    install_packages nodejs && npm i -g yarn

# Add app user
RUN groupadd -g 1001 app && \
    useradd -u 1001 -g app app --home $APP_HOME

# Some Rubygems (libraries) assume that they can write to tmp/ within the Rails
# app's base directory.
RUN mkdir -p $APP_HOME && ln -fs /tmp $APP_HOME

# Make irb log history to a file
RUN echo 'IRB.conf[:HISTORY_FILE] = "/tmp/irb_history"' > "$IRBRC"

LABEL org.opencontainers.image.source=https://github.com/alphagov/govuk-ruby-images
