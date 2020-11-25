FROM php:7-apache-buster

ARG BUILD_VERSION=1.3.9
ARG BUILD_DATE=2020-11-23
ARG DEBIAN_FRONTEND=noninteractive

LABEL maintainer="trw@acoby.de"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.name="acoby/mailpiler"
LABEL org.label-schema.description="Mailpiler"
LABEL org.label-schema.url="http://www.acoby.de/"
LABEL org.label-schema.vcs-url="https://gitlab.acoby.de/acoby/mailpiler/"
LABEL org.label-schema.vendor="Acoby GmbH"
LABEL org.label-schema.version=$BUILD_VERSION


RUN apt-get update && \
    apt-get install -y \
      build-essential automake autoconf libtool git sysstat wget curl && \
    apt-get clean

RUN apt-get install -y libzip-dev libzip4 zip && \
    apt-get clean && \
    docker-php-ext-configure zip && \
    docker-php-ext-install zip

#RUN apt-get install -y libmemcached11 libmemcachedutil2 libmemcached-dev && \
#    apt-get clean && \
#    git clone https://github.com/php-memcached-dev/php-memcached /usr/src/php/ext/memcached && \
#    cd /usr/src/php/ext/memcached && git checkout -b php7 origin/php7 && \
#    docker-php-ext-configure memcached --disable-memcached-sasl &&\
#    docker-php-ext-install memcached

RUN apt-get install -y libfreetype6-dev libpng-dev libjpeg62-turbo-dev && \
    apt-get clean && \
    docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install gd

RUN apt-get install -y libc-client2007e-dev libkrb5-dev libonig-dev && \
    apt-get clean && \
    docker-php-ext-configure imap --with-imap-ssl --with-kerberos && \
    docker-php-ext-install imap

RUN docker-php-ext-install pdo pdo_mysql mbstring

RUN curl -L https://download.mailpiler.com/generic-local/sphinx-3.1.1-bin.tar.gz | tar -xzC /

RUN apt-get install -y cron \
      libtre5 libtre-dev \
      libmariadb3 libmariadbclient-dev python python-mysqldb mariadb-client \
      libwrap0-dev \
      libpoppler-dev xpdf catdoc unrtf tnef nano \
      gettext && \
    apt-get clean && \
    mkdir -p /usr/src/piler && \
    adduser --shell /bin/sh --home /var/piler --disabled-login piler && \
    passwd -dl piler || true && \
    curl -L https://bitbucket.org/jsuto/piler/downloads/piler-${BUILD_VERSION}.tar.gz  | tar --strip-components=1 -xzC /usr/src/piler && \
    cd /usr/src/piler && \
    ./configure --localstatedir=/var --with-database=mariadb && \
    make && \
    make install && \
    chmod 6755 /usr/local/bin/piler* /usr/local/bin/reindex && \
    sed -e'/load_default_values$/q' ./util/postinstall.sh > /tmp/postinstall.sh && \
    cd /tmp && \
#   echo "make_cron_entries\ncrontab -u piler < $CRON_TMP\nclean_up_temp_stuff" >> postinstall.sh && \
    bash postinstall.sh && \
    rm postinstall.sh && \
    ln -s /usr/local/bin/php /usr/bin/php && \
    ln -s /usr/local/lib/libpiler.so* /usr/lib/.


RUN a2enmod rewrite
RUN a2enmod headers

COPY apache.conf /etc/apache2/conf-enabled/x-security.conf
COPY run.sh /sbin/run.sh

RUN chmod 755 /sbin/run.sh

HEALTHCHECK --interval=60s --timeout=5s --start-period=5s CMD curl --fail http://localhost/ || exit 1

EXPOSE 25/tcp
EXPOSE 80/tcp
EXPOSE 443/tcp

CMD ["/sbin/run.sh"]