#!/bin/bash -e
[ -n "$DEBUG" ] && set -x

PILER_HOST=${PILER_HOST:-archive.example.org}

echo "Creating database"
mysql -h "$MYSQL_HOST" -u "$MYSQL_USER" --password="$MYSQL_PASSWORD" "$MYSQL_DATABASE" < "/usr/local/share/piler/db-mysql.sql" || true

echo "Writing sphinx configuration"
sed -e "s%MYSQL_HOSTNAME%${MYSQL_HOST}%" \
    -e "s%MYSQL_DATABASE%${MYSQL_DATABASE}%" \
    -e "s%MYSQL_USERNAME%${MYSQL_USER}%" \
    -e "s%MYSQL_PASSWORD%${MYSQL_PASSWORD}%" \
    -e "s%SPHINX_VERSION < 300%SPHINX_VERSION < 312%" \
    -e "s%321%311%" \
   "/usr/local/etc/piler/sphinx.conf.dist" > "/usr/local/etc/piler/sphinx.conf"

echo "Initializing sphinx indices"
su piler -c "indexer --all --config /usr/local/etc/piler/sphinx.conf" || true

echo "Writing piler configuration"
PILER_CONF=/usr/local/etc/piler/piler.conf
if [[ ! -f "$PILER_CONF" ]]; then
  cp /usr/local/etc/piler/piler.conf.dist "$PILER_CONF"
  chmod 640 "$PILER_CONF"
  chown root:piler "$PILER_CONF"
  sed -i "s%hostid=.*%hostid=${PILER_HOST%%:*}%" "$PILER_CONF"
  sed -i "s%tls_enable=.*%tls_enable=1%" "$PILER_CONF"
  sed -i "s%mysqlpwd=.*%mysqlpwd=${MYSQL_PASSWORD}%" "$PILER_CONF"
fi

# First-time config
if [ ! -f /var/www/piler/config-site.php ]; then
  echo "Creating webroot scripts"
  sed -e'/load_default_values$/q' /usr/src/piler/util/postinstall.sh > /tmp/postinstall.sh
  cd /usr/src/piler
  (set +e
    source /tmp/postinstall.sh
    preinstall_check

    export PILERUSER=piler
    export WWWGROUP="www-data"
    export MYSQL_HOSTNAME=${MYSQL_HOST:-piler}
    export MYSQL_DATABASE=${MYSQL_DATABASE:-piler}
    export MYSQL_USERNAME=${MYSQL_USER:-piler}
    export MYSQL_PASSWORD=${MYSQL_PASSWORD:-piler}
    export SMARTHOST=${SMARTHOST:-smarthost.example.org}
    export SMARTHOST_PORT=${SMARTHOST_PORT:-25}
    export DOCROOT="/var/www/html"
    export SSL_CERT_DATA="/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com"
    export SCRIPT_DIR="/usr/src/piler/util/"

    make_cron_entries
    if [ -d webui ]; then
      echo -n "Copying www files to $DOCROOT... "
      mkdir -p $DOCROOT || exit 1
      cp -R webui/* $DOCROOT
      cp -R webui/.htaccess $DOCROOT
    fi
    webui_install
    clean_up_temp_stuff
  )
fi

# Start crond for piler tasks
echo "Configure cron"
if [ -f /usr/local/etc/piler/crontab.piler ]; then
  crontab -u piler /usr/local/etc/piler/crontab.piler
fi
echo "Run Cron Daemon"
/etc/init.d/cron start

echo "Run Search Daemon"
/etc/init.d/rc.searchd start

echo "Run Piler Daemon"
nohup /etc/init.d/rc.piler start &

echo "Start Webserver..."
exec apache2-foreground

#eof