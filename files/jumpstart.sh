#!/bin/bash

if [[ ! -e /opt/installed.fin ]]; then

DATABASE_PASS="$(pwgen -1s 32)"
UWP_PASS="$(pwgen -1s 32)"
BLOWFISH_PASS="$(pwgen -1s 32)"

# Store the generated mysql passwords under /root
echo ${DATABASE_PASS} > /root/mysql-root
echo ${UWP_PASS} > /root/mysql-uwp

# Generate phpmyadmin config
cat << EOF > /var/www/html/phpmyadmin/config.inc.php
<?php
\$cfg['blowfish_secret'] = '${BLOWFISH_PASS}';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['connect_type'] = 'socket';
\$cfg['ZeroConf'] = 'false';
\$cfg['VersionCheck'] = 'false';
\$cfg['PmaNoRelation_DisableWarning'] = 'true';
\$cfg['DefaultConnectionCollation'] = 'utf8mb4_unicode_ci';
?>
EOF

# Generate mysql config
cat << EOF > /etc/my.cnf
[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4

[client-server]
socket = /var/lib/mysql/mysql.sock

[mysqld]
skip-networking
innodb_buffer_pool_size = ${MYSQL_MEM:-64M}
init-connect = 'SET NAMES utf8mb4'
collation-server = utf8mb4_unicode_ci
character-set-server = utf8mb4
pid-file = /var/lib/mysql/mysql.pid
log-error = /var/lib/mysql/mysql.err
log-warnings = 0

!includedir /etc/my.cnf.d
EOF

# Generate php-fpm config
cat << EOF > /etc/php-fpm.d/www.conf
[www]
listen = /var/run/php-fpm/php.sock
listen.owner = nginx
listen.group = nginx

user = nginx
group = nginx

pm = dynamic
pm.max_children = ${PHP_CHILDREN:-15}
pm.start_servers = 5
pm.min_spare_servers = 3
pm.max_spare_servers = 7
pm.max_requests = 500

php_admin_value[error_log] = /var/log/php-fpm/error.log
php_admin_flag[log_errors] = on
php_admin_value[memory_limit] = ${PHP_MEM:-64M}

php_value[session.save_handler] = files
php_value[session.save_path]    = /var/lib/php-fpm/session
php_value[soap.wsdl_cache_dir]  = /var/lib/php-fpm/wsdlcache
EOF

# Generate nginx config
cat << 'EOF' > /etc/nginx/nginx.conf
daemon off;
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log error;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent"';

    access_log  off;

    server_tokens   off;
    charset         utf-8;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    client_max_body_size 8m;
    keepalive_timeout    30;
    client_body_timeout  30;
    reset_timedout_connection on;

    index           index.php;

    gzip            on;
    gzip_disable    "msie6";
    gzip_vary       on;
    gzip_proxied    any;
    gzip_comp_level 5;
    gzip_min_length 1k;
    gzip_buffers    32 4k;
    gzip_types text/css
               text/javascript
               text/xml
               text/plain
               application/javascript
               application/json
               application/xml
               application/atom+xml
               image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
}
EOF

# Set permissions for nginx
chown -R nginx. /var/www/html/{wordpress,phpmyadmin}/
chgrp nginx /var/lib/php-fpm/*/

# Delete the default nginx virtualhost
>/etc/nginx/conf.d/default.conf

# Lower the opcache shared memory storage and cached files
sed -i -e "s/128/${OPCACHE_MEM:-96}/" -e 's/4000/2000/' /etc/php.d/10-opcache.ini

# Disable php extensions: calendar, sqlite3, xsl, xmlwriter, phar, pdo, pdo_mysql, pdo_sqlite, mysql, wddx
sed -i 's/^extension/;extension/' /etc/php.d/20-{calendar,pdo,phar,sqlite3,xmlwriter,xsl}.ini /etc/php.d/30-{mysql,pdo_mysql,pdo_sqlite,wddx}.ini

# Disable php expose, lower memory to 64M, increase execution time to 60s, set session path and timezone to UTC
sed -i -e 's/^expose_php = On/expose_php = Off/' -e 's/^max_execution_time = 30/max_execution_time = 60/' -e "s/^memory_limit = 128M/memory_limit = ${PHP_MEM:-64M}/" -e 's/^;date.timezone =/date.timezone = "UTC"/' -e 's|^;session.save_path = "/tmp"|session.save_path = "/var/lib/php-fpm/session"|' /etc/php.ini

# Disable php-fpm background daemon
sed -i 's/^daemonize = yes/daemonize = no/' /etc/php-fpm.conf

# Disable opcache for phpmyadmin
echo '/var/www/html/phpmyadmin' > /etc/php.d/opcache-default.blacklist

mv /var/www/html/wordpress/wp-config{-sample.php,.php}

# Configure wordpress database credentials, increase memory limit to 64M, set auth keys and salts, change table prefix
curl -q -s https://api.wordpress.org/secret-key/1.1/salt/ -o /tmp/auth_salts.txt
sed -i -e 's/database_name_here/uwp/' -e 's/username_here/uwp_user/' -e "s/password_here/${UWP_PASS}/" -e "/DB_COLLATE/a define('WP_MEMORY_LIMIT', '${PHP_MEM:-64M}');" -e '/put your unique phrase here/d' -e '/DB_COLLATE/r /tmp/auth_salts.txt' /var/www/html/wordpress/wp-config.php

service mysql start

# mysql_secure_installation and wordpress database/user creation
mysqladmin -u root password "${DATABASE_PASS}"
mysql -u root -p"${DATABASE_PASS}" << EOF
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db LIKE 'test%';
DROP DATABASE test;
FLUSH PRIVILEGES;
CREATE DATABASE uwp;
GRANT ALL ON uwp.* TO 'uwp_user'@'localhost' IDENTIFIED BY '${UWP_PASS}';
FLUSH PRIVILEGES;
EOF

service mysql stop

# Clean up files
rm -rf /var/www/html/phpmyadmin/{setup,examples}/
rm -f /var/www/html/phpmyadmin/{ChangeLog,README,RELEASE-DATE-4.4.12}
rm -f /var/www/html/wordpress/wp-content/plugins/hello.php /var/www/html/wordpress/readme.html /tmp/*

echo 'Install complete.' > /opt/installed.fin

supervisorctl start uwp:* && exit 0

else

supervisorctl start uwp:* && exit 0

fi
