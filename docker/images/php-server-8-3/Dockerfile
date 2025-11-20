###############################################################################
# Базовые шаги сборки, которые необходимы и локально, и на серверах.
###############################################################################
FROM php:8.3-fpm-bookworm AS base

# Установка NGINX
ENV NGINX_VERSION   1.28.0
ENV NJS_VERSION     0.8.10
ENV NJS_RELEASE     1~bookworm
ENV PKG_RELEASE     1~bookworm
ENV DYNPKG_RELEASE  1~bookworm

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && groupadd --system --gid 101 nginx \
    && useradd --system --gid nginx --no-create-home --home /nonexistent --comment "nginx user" --shell /bin/false --uid 101 nginx \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y gnupg1 ca-certificates \
    && \
    NGINX_GPGKEYS="573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 8540A6F18833A80E9C1653A42FD21310B49F6B46 9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3"; \
    NGINX_GPGKEY_PATH=/etc/apt/keyrings/nginx-archive-keyring.gpg; \
    export GNUPGHOME="$(mktemp -d)"; \
    found=''; \
    for NGINX_GPGKEY in $NGINX_GPGKEYS; do \
    for server in \
        hkp://keyserver.ubuntu.com:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
        gpg1 --batch --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
    done; \
    gpg1 --batch --export $NGINX_GPGKEYS > "$NGINX_GPGKEY_PATH" ; \
    rm -rf "$GNUPGHOME"; \
    apt-get remove --purge --auto-remove -y gnupg1 && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${NJS_RELEASE} \
    " \
    && case "$dpkgArch" in \
        amd64|arm64) \
# arches officialy built by upstream
            echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://nginx.org/packages/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list \
            && apt-get update \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
# new directory for storing sources and .deb files
            tempDir="$(mktemp -d)" \
            && chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
            \
# save list of currently-installed packages so build dependencies can be cleanly removed later
            && savedAptMark="$(apt-mark showmanual)" \
            \
# build .deb files from upstream's packaging sources
            && apt-get update \
            && apt-get install --no-install-recommends --no-install-suggests -y \
                curl \
                devscripts \
                equivs \
                git \
                libxml2-utils \
                lsb-release \
                xsltproc \
            && ( \
                cd "$tempDir" \
                && REVISION="${NGINX_VERSION}-${PKG_RELEASE}" \
                && REVISION=${REVISION%~*} \
                && curl -f -L -O https://github.com/nginx/pkg-oss/archive/${REVISION}.tar.gz \
                && PKGOSSCHECKSUM="517bc18954ccf4efddd51986584ca1f37966833ad342a297e1fe58fd0faf14c5a4dabcb23519dca433878a2927a95d6bea05a6749ee2fa67a33bf24cdc41b1e4 *${REVISION}.tar.gz" \
                && if [ "$(openssl sha512 -r ${REVISION}.tar.gz)" = "$PKGOSSCHECKSUM" ]; then \
                    echo "pkg-oss tarball checksum verification succeeded!"; \
                else \
                    echo "pkg-oss tarball checksum verification failed!"; \
                    exit 1; \
                fi \
                && tar xzvf ${REVISION}.tar.gz \
                && cd pkg-oss-${REVISION} \
                && cd debian \
                && for target in base module-geoip module-image-filter module-njs module-xslt; do \
                    make rules-$target; \
                    mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes" \
                        debuild-$target/nginx-$NGINX_VERSION/debian/control; \
                done \
                && make base module-geoip module-image-filter module-njs module-xslt \
            ) \
# we don't remove APT lists here because they get re-downloaded and removed later
            \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
            && apt-mark showmanual | xargs apt-mark auto > /dev/null \
            && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
            \
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
            && ls -lAFh "$tempDir" \
            && ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
            && grep '^Package: ' "$tempDir/Packages" \
            && echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
            && apt-get -o Acquire::GzipIndexes=false update \
            ;; \
    esac \
    \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        gettext-base \
                        curl \
    && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove \
        && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /var/opt/docker-entrypoint.d

# Установка расширений и программ
RUN --mount=type=bind,from=mlocati/php-extension-installer:2,source=/usr/bin/install-php-extensions,target=/usr/local/bin/install-php-extensions \
    install-php-extensions xdebug

RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y gosu \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && curl -fsSL https://getcomposer.org/installer | php -- --version=2.8.10 --install-dir=/usr/bin/ --filename=composer \
    && curl -fsSL https://quobix.com/scripts/install_vacuum.sh | VERSION='0.17.6' INSTALL_DIR='/usr/bin' sh

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx/conf.d /etc/nginx/conf.d
COPY nginx/docker-entrypoint.sh /var/opt/nginx/
COPY nginx/10-listen-on-ipv6-by-default.sh /var/opt/nginx/docker-entrypoint.d/
COPY nginx/15-local-resolvers.envsh /var/opt/nginx/docker-entrypoint.d/
COPY nginx/20-envsubst-on-templates.sh /var/opt/nginx/docker-entrypoint.d/
COPY nginx/30-tune-worker-processes.sh /var/opt/nginx/docker-entrypoint.d/

# Настройка php
COPY php.ini /usr/local/etc/php/php.ini
COPY php.ini-base /usr/local/etc/php/conf.d/01-php.ini
COPY php.ini-development /usr/local/etc/php/conf.d/02-php.ini

RUN chmod +x /var/opt/nginx/docker-entrypoint.sh
RUN chmod +x -R /var/opt/nginx/docker-entrypoint.d/

ENTRYPOINT ["/var/opt/nginx/docker-entrypoint.sh"]

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
