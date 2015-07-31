# uWP
micro WordPress Docker image tuned for low resource environments.

Image is based on [centos:6](https://registry.hub.docker.com/_/centos/) docker image.

The defaults are 64MB php memory limit, opcode cache 96MB, innodb buffer pool 64MB.

When built the image will expose ports 80 (WordPress) and 81 (phpMyAdmin). The virtual hosts by default use ```localhost``` as their server name.

The virtual hosts are located under files/nginx so you can edit the server_name to match your setup.

The latest stable versions are always downloaded.

Auto generated mysql passwords can be found under ```/root/mysql-root``` and ```/root/mysql-uwp```.

A database called ```uwp``` will be automatically created and owned by the ```uwp_user```.

On the first run, the jumpstart script will setup the system, exit, and then run the supervisor group uwp(nginx, php, mysql).

Supervisord controls the services, so you can see the status of the whole group with

```
# supervisorctl status uwp:*
```

Image setup consists of nginx, php-fpm, and mariadb.

The image exposes two volumes: ```/var/www/html``` and ```/var/lib/mysql```.

TL;DR:

```
# docker pull goll/uwp
# docker run -d -p 80:80 -p 81:81 goll/uwp
```

Open your browser and go to ```http://localhost``` and ```http://localhost:81```.
