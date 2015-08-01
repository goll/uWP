FROM centos:6
MAINTAINER Adrian Goll <goll[at]kset.org>

EXPOSE 80 81

ENV TERM=xterm IUS='https://dl.iuscommunity.org/pub/ius/stable/CentOS/6/x86_64/'

COPY ./files/yum.repos.d/ /etc/yum.repos.d/

RUN yum -q history new && \
rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6 https://yum.mariadb.org/RPM-GPG-KEY-MariaDB http://nginx.org/keys/nginx_signing.key && \
curl -q -s ${IUS}"$(curl -q -s ${IUS} | LC_ALL=C egrep -m1 -o 'ius-release[^"]+rpm')" -o /tmp/ius.rpm && \
yum -q -y install epel-release /tmp/ius.rpm && \
rpm --quiet --import /etc/pki/rpm-gpg/{IUS-COMMUNITY-GPG-KEY,RPM-GPG-KEY-EPEL-6} && \
yum -q clean all

RUN yum -q -y update && \
yum -q -y install MariaDB-server nginx php56u{-fpm,-gd,-mbstring,-mcrypt,-mysqlnd,-opcache} python-setuptools pwgen tar && \
yum -q clean all && \
easy_install -q supervisor && \
mkdir /var/log/supervisor

WORKDIR /var/www/html

RUN curl -q -s https://wordpress.org/latest.tar.gz | tar xz && \
curl -q -s "$(curl -q -s https://www.phpmyadmin.net/downloads/ | LC_ALL=C egrep -m1 -o 'https[^"]+english.tar.gz')" | tar xz && \
mv {php*,phpmyadmin}

COPY ./files/supervisor/ /etc/
COPY ./files/nginx/ /etc/nginx/conf.d/
COPY ./files/jumpstart.sh /opt/

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]

VOLUME ["/var/www/html", "/var/lib/mysql"]
