FROM centos:6
MAINTAINER Adrian Goll <goll[at]kset.org>

EXPOSE 80 81

ENV TERM=xterm

COPY ./files/yum.repos.d/ /etc/yum.repos.d/
COPY ./files/mariadb/ /etc/
COPY ./files/supervisor/ /etc/
COPY ./files/nginx/ /etc/nginx/conf.d/

RUN rpm --quiet --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6 https://yum.mariadb.org/RPM-GPG-KEY-MariaDB http://nginx.org/keys/nginx_signing.key && \
yum -q -y install https://centos6.iuscommunity.org/ius-release.rpm && \
rpm --quiet --import /etc/pki/rpm-gpg/{RPM-GPG-KEY-EPEL-6,IUS-COMMUNITY-GPG-KEY} && \
yum -q clean all

RUN yum -q -y update && \
yum -q -y install MariaDB-server nginx php56u{-fpm,-gd,-mbstring,-mcrypt,-mysqlnd,-opcache} python-setuptools pwgen tar && \
yum -q clean all && \
easy_install -q supervisor && \
mkdir /var/log/supervisor

COPY ./files/jumpstart.sh /opt/

CMD ["/usr/bin/supervisord", "--configuration=/etc/supervisord.conf"]

VOLUME ["/var/www/html", "/var/lib/mysql"]
