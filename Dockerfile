FROM alpine:latest

ENV OPENRESTY_VERSION 1.21.4.1
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
ENV PATH="${OPENRESTY_PREFIX}/bin:${PATH}"

# Docker Build Arguments
ARG RESTY_VERSION="1.21.4.1"
ARG RESTY_OPENSSL_VERSION="1.1.1m"
ARG RESTY_PCRE2_VERSION="10.39"
ARG RESTY_PCRE_VERSION="8.45"
ARG RESTY_J="12"
ARG RESTY_WAF_VERSION="0.11.1"
ARG LUAROCKS_VERSION="3.0.4"
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
ARG RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION} --add-module=/tmp/ngx_cache_purge-2.3 --add-dynamic-module=/tmp/ngx_http_redis-0.3.9 "
ARG LUA_LIB_DIR=${OPENRESTY_PREFIX}/lualib

# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Build lua-resty-waf
# 5) Cleanup

RUN \
    apk add --no-cache --virtual .build-deps \
        build-base \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        linux-headers \
        make \
        perl-dev \
        readline-dev \
        zlib-dev \
        lua5.1-dev \
        pcre-dev \
    && apk add --no-cache \
        coreutils openssl \
        curl tree \
        gd \
        geoip \
        libgcc \
        libxslt \
        zlib \
        git \
        libstdc++ \
        python2 \
        bash \
        lua5.1-rex-pcre \
        pcre pcre-tools \
        unzip \
    && cd /tmp && mkdir -p ${OPENRESTY_PREFIX}/lualib \
    && curl -fsSLk https://people.freebsd.org/~osa/ngx_http_redis-0.3.9.tar.gz -o ngx_http_redis-0.3.9.tar.gz \
    && tar zxf ngx_http_redis-0.3.9.tar.gz \
    && curl -fsSLk http://labs.frickle.com/files/ngx_cache_purge-2.3.tar.gz -o ngx_cache_purge-2.3.tar.gz \
    && tar zxf ngx_cache_purge-2.3.tar.gz \
    && echo "curl https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz" \
    && curl -fsSLk https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && echo "curl https://sourceforge.net/projects/pcre/files/pcre/${RESTY_PCRE_VERSION}/pcre-${RESTY_PCRE_VERSION}.tar.gz/download" \
    && curl -fsSLk https://sourceforge.net/projects/pcre/files/pcre/${RESTY_PCRE_VERSION}/pcre-${RESTY_PCRE_VERSION}.tar.gz/download -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && echo "curl https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz" \
    && curl -fsSLk https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && echo "curl https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz -o luarocks-${LUAROCKS_VERSION}.tar.gz" \
    && curl -fsSLk https://luarocks.org/releases/luarocks-${LUAROCKS_VERSION}.tar.gz -o luarocks-${LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${LUAROCKS_VERSION}.tar.gz \
    && cd /tmp/luarocks-${LUAROCKS_VERSION} \
    && ./configure \
    && make bootstrap \
    && cd /tmp/openresty-${RESTY_VERSION}/bundle/nginx-1.21.4/ \
    && sed -i 's@"nginx/"@"-/"@g' src/core/nginx.h \
    && sed -i 's@r->headers_out.server == NULL@0@g' src/http/ngx_http_header_filter_module.c \
    && sed -i 's@r->headers_out.server == NULL@0@g' src/http/v2/ngx_http_v2_filter_module.c \
    && sed -i 's@<hr><center>nginx</center>@@g' src/http/ngx_http_special_response.c \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && git clone https://github.com/p0pr0ck5/lua-resty-waf.git --recursive \
    && cd lua-resty-waf \
    && wget -O src/decode.c https://raw.githubusercontent.com/p0pr0ck5/lua-resty-waf/96b0a04ce62dd01b6c6c8a8c97df7ce9916d173e/src/decode.c \
    && make \
    && make install \
    && apk del .build-deps \
    && ln -sf ${NGINX_PREFIX}/sbin/nginx /usr/local/bin/nginx \
    && ln -s /usr/lib/lua/5.1/rex_pcre.so ${OPENRESTY_PREFIX}/lualib/ \
    && ln -s /usr/lib/lua/5.1/rex_pcre.so.2.9 ${OPENRESTY_PREFIX}/lualib/ \
    && rm -fr /tmp/* ${NGINX_PREFIX}/conf/*.default \
    && mkdir -p /var/nginx /etc/nginx/ssl ${NGINX_PREFIX}/proxy_temp \
    && echo -e "#!/bin/sh\nulimit -n 200000\nnginx\n" > /start.sh \
    && chown nobody:nobody ${NGINX_PREFIX}/proxy_temp \
    && chmod +x /start.sh \
    && rm -fr /root/.opm/cache 

WORKDIR $NGINX_PREFIX/conf

COPY ./*.lua ${OPENRESTY_PREFIX}/lualib/resty/
COPY ./conf/ ${NGINX_PREFIX}/conf/

EXPOSE 80 443

ENTRYPOINT ["/start.sh"]
