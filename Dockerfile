FROM alpine:latest

ENV OPENRESTY_VERSION 1.13.6.1
ENV OPENRESTY_PREFIX /opt/openresty
ENV NGINX_PREFIX /opt/openresty/nginx
ENV VAR_PREFIX /opt/openresty/nginx/var
ENV VAR_LOG_PREFIX /opt/openresty/nginx/logs

# NginX prefix is automatically set by OpenResty to $OPENRESTY_PREFIX/nginx
# look for $ngx_prefix in https://github.com/openresty/ngx_openresty/blob/master/util/configure

# Timezone
ENV TIMEZONE Asia/Bangkok
RUN echo "Install Timezone ===========>>" \
 && apk add --update tzdata \
 && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
 && echo "${TIMEZONE}" > /etc/timezone

# ENV FOR RESTY FIX FOR RUN OPM
ENV PATH="/opt/openresty/bin:${PATH}"

# Docker Build Arguments
ARG RESTY_VERSION="1.13.6.1"
ARG RESTY_OPENSSL_VERSION="1.0.2l"
ARG RESTY_PCRE_VERSION="8.39"
ARG RESTY_J="8"
ARG RESTY_WAF_VERSION="0.11.1"
ARG LUAROCKS_VERSION="2.4.2"
ARG RESTY_CONFIG_OPTIONS="\
    --prefix=${OPENRESTY_PREFIX} \
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    "

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"


# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Build lua-resty-waf
# 5) Cleanup

RUN \
    apk add --no-cache --virtual .build-deps \
        build-base \
        curl \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
    && apk add --no-cache \
        gd \
        geoip \
        libgcc \
        libxslt \
        zlib \
        git \
        libstdc++ \
        python \
        lua5.1-dev \
        bash \
	lua5.1-rex-pcre \
    && cd /tmp \
    && curl -fSLk https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSLk https://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSLk https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && curl -fSLk https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz -o luarocks-${LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${LUAROCKS_VERSION}.tar.gz \
    && cd /tmp/luarocks-${LUAROCKS_VERSION} \
    && ./configure \
    && make bootstrap \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /opt/openresty \
    && git clone https://github.com/p0pr0ck5/lua-resty-waf.git --recursive \
    && cd lua-resty-waf \
    && make \
    && make install \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
        luarocks-${LUAROCKS_VERSION}.tar.gz luarocks-${LUAROCKS_VERSION} \
    && apk del .build-deps \
    && ln -sf /dev/stdout /opt/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /opt/openresty/nginx/logs/error.log \
    && ln -sf /opt/openresty/nginx/sbin/nginx /usr/local/bin/nginx \
    && ln -s /usr/lib/lua/5.1/rex_pcre.so /opt/openresty/lualib/ \
    && ln -s /usr/lib/lua/5.1/rex_pcre.so.2.8 /opt/openresty/lualib/ \
    && rm -fr /opt/openresty/lua-resty-waf

WORKDIR $NGINX_PREFIX

ONBUILD COPY nginx $NGINX_PREFIX/

COPY ./conf/ /$NGINX_PREFIX/conf/
ADD  ./start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80 443

ENTRYPOINT ["/start.sh",""]
