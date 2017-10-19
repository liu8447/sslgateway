FROM alpine:3.6

LABEL maintainer="SSLGW Docker Maintainers <liu8447@hotmail.com>"

ENV SSLGW 1.1.4

RUN GPG_KEYS=A0E98066 \
	&& BASEPATH=sslgateway \
	&& NAMEVAR=sslgw \
	&& OPENRESTY_VERSION=1.11.2.5 \
	&& NGINX_VERSION=1.11.2 \
	&& CONFIG="\
		--prefix=/etc/${BASEPATH} \
		--sbin-path=/usr/sbin/${NAMEVAR} \
		--modules-path=/usr/lib/${BASEPATH}/modules \
		--conf-path=/etc/${BASEPATH}/conf/${NAMEVAR}.conf \
		--error-log-path=/var/log/${BASEPATH}/${NAMEVAR}_error.log \
		--http-log-path=/var/log/${BASEPATH}/${NAMEVAR}_access.log \
		--pid-path=/var/run/${NAMEVAR}.pid \
		--lock-path=/var/run/${NAMEVAR}.lock \
		--http-client-body-temp-path=/var/cache/${BASEPATH}/client_temp \
		--http-proxy-temp-path=/var/cache/${BASEPATH}/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/${BASEPATH}/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/${BASEPATH}/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/${BASEPATH}/scgi_temp \
		--user=${NAMEVAR} \
		--group=${BASEPATH} \
		--with-luajit \
    --with-md5-asm \
    --with-sha1-asm \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-http_perl_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-file-aio \
		--with-http_v2_module \
	" \
	&& addgroup -S ${BASEPATH} \
	&& adduser -D -S -h /var/cache/${BASEPATH} -s /sbin/nologin -G ${BASEPATH} ${NAMEVAR} \
	&& apk add --update --no-cache --virtual .build-deps \
		gcc \
		readline-dev \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		valgrind-dev \
		perl-dev \
	&& curl -fSL http://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz -o openresty.tar.gz \
	&& curl -fSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz.asc  -o openresty.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& found=''; \
	for server in \
		pgp.mit.edu \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
	; do \
		echo "Fetching GPG key $GPG_KEYS from $server"; \
		gpg --keyserver "$server" --keyserver-options timeout=100 --recv-keys "$GPG_KEYS" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
	gpg --batch --verify openresty.tar.gz.asc openresty.tar.gz \
	&& echo "GPG $GNUPGHOME" \
	&& rm -rf "$GNUPGHOME" openresty.tar.gz.asc \
	&& tar -zxC /root -f openresty.tar.gz \
	&& rm openresty.tar.gz \
	&& cd /root/openresty-$OPENRESTY_VERSION \
	&& sed -i "s#prefix/nginx#prefix/sslgateway#" configure \
	&& sed -i "s#openresty#openresty#" configure \
	&& sed -i "s#\"NGINX\"#\"$NAMEVAR\"#" bundle/nginx-${NGINX_VERSION}/src/core/nginx.h \
  && sed -i "s#\"openresty/\"#\"$NAMEVAR/\"#" bundle/nginx-${NGINX_VERSION}/src/core/nginx.h \
  && sed -i "s#\"nginx version: \"#\"$NAMEVAR version:\"#" bundle/nginx-${NGINX_VERSION}/src/core/nginx.c \
  && sed -i "s#Usage: nginx#Usage: ${NAMEVAR}#" bundle/nginx-${NGINX_VERSION}/src/core/nginx.c \
	&& sed -i "s#Server: openresty#Server: $NAMEVAR#" bundle/nginx-${NGINX_VERSION}/src/http/ngx_http_header_filter_module.c \
	&& sed -i "s#\"<hr><center>openresty<\/center>\"#\"<hr><center>$NAMEVAR<\/center>\"#" bundle/nginx-${NGINX_VERSION}/src/http/ngx_http_special_response.c \
	&& sed -i "s#\"nginx\"#\"$NAMEVAR\"#" bundle/nginx-${NGINX_VERSION}/src/http/v2/ngx_http_v2_filter_module.c \
	&& ./configure $CONFIG --with-debug --with-luajit-xcflags='-DLUAJIT_USE_SYSMALLOC -DLUAJIT_USE_VALGRIND' \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& mkdir debug \
	&& mv build/nginx-${NGINX_VERSION}/objs/nginx debug/nginx-debug \
	&& mv build/nginx-${NGINX_VERSION}/objs/ngx_http_xslt_filter_module.so debug/ngx_http_xslt_filter_module-debug.so \
	&& mv build/nginx-${NGINX_VERSION}/objs/ngx_http_image_filter_module.so debug/ngx_http_image_filter_module-debug.so \
	&& mv build/nginx-${NGINX_VERSION}/objs/ngx_http_geoip_module.so debug/ngx_http_geoip_module-debug.so \
	&& mv build/nginx-${NGINX_VERSION}/objs/ngx_http_perl_module.so debug/ngx_http_perl_module-debug.so \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/${BASEPATH}/nginx/html/ \
	&& rm -rf /etc/${BASEPATH}/bin/openresty \
	#&& mkdir /etc/${BASEPATH}/conf.d/ 
	&& install -m755 debug/nginx-debug /usr/sbin/${NAMEVAR}-debug \
	&& install -m755 debug/ngx_http_xslt_filter_module-debug.so /usr/lib/${BASEPATH}/modules/ngx_http_xslt_filter_module-debug.so \
	&& install -m755 debug/ngx_http_image_filter_module-debug.so /usr/lib/${BASEPATH}/modules/ngx_http_image_filter_module-debug.so \
	&& install -m755 debug/ngx_http_geoip_module-debug.so /usr/lib/${BASEPATH}/modules/ngx_http_geoip_module-debug.so \
	&& install -m755 debug/ngx_http_perl_module-debug.so /usr/lib/${BASEPATH}/modules/ngx_http_perl_module-debug.so \
	&& ln -s /usr/lib/${BASEPATH}/modules /etc/${BASEPATH}/modules \
	&& strip /usr/sbin/${NAMEVAR}* \
	&& strip /usr/lib/${BASEPATH}/modules/*.so \
	&& rm -rf /root/openresty-$OPENRESTY_VERSION \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/sbin/${NAMEVAR} /usr/lib/${BASEPATH}/modules/*.so /tmp/envsubst \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps gcc \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# forward request and error logs to docker log collector
	&& rm -rf /etc/${BASEPATH}/nginx \
	&& ln -sf /dev/stdout /var/log/${BASEPATH}/${NAMEVAR}_access.log \
	&& ln -sf /dev/stderr /var/log/${BASEPATH}/${NAMEVAR}_error.log


EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["sslgw", "-g", "daemon off;"]
