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

LABEL org.opencontainers.image.source=https://github.com/alphagov/govuk-ruby-images
