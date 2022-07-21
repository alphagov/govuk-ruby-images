FROM bitnami/minideb:bullseye AS builder

ARG RUBY_MAJOR RUBY_VERSION RUBY_DOWNLOAD_SHA256

ENV LANG=C.UTF-8 \
  RUBY_MAJOR=${RUBY_MAJOR} \
  RUBY_VERSION=${RUBY_VERSION} \
  RUBY_DOWNLOAD_SHA256=${RUBY_DOWNLOAD_SHA256}

RUN install_packages build-essential bison dpkg-dev libgdbm-dev ruby wget autoconf libssl-dev zlib1g-dev libreadline-dev

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
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
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
	; \
	make -j "$(nproc)"; \
	make install;

FROM bitnami/minideb:bullseye

COPY --from=builder /build /

ENV GEM_HOME=/usr/local/bundle \
	BUNDLE_APP_CONFIG=/usr/local/bundle \
	RAILS_LOG_TO_STDOUT=1 \
	RAILS_ENV=production \
	NODE_ENV=production \
	BUNDLE_WITHOUT="development test" \
	GOVUK_APP_DOMAIN=www.gov.uk \
	GOVUK_WEBSITE_ROOT=https://www.gov.uk \
	GOVUK_PROMETHEUS_EXPORTER=true

RUN install_packages ca-certificates curl gpg build-essential && \
	curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee "/usr/share/keyrings/nodesource.gpg" >/dev/null && \
	echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x bullseye main" | tee /etc/apt/sources.list.d/nodesource.list && \
	install_packages nodejs && npm i -g yarn

RUN groupadd -g 1001 app && \
	useradd -u 1001 -g app app --home /app

RUN echo 'IRB.conf[:HISTORY_FILE] = "/tmp/irb_history"' > irb.rc

LABEL org.opencontainers.image.source=https://github.com/alphagov/govuk-ruby-images
