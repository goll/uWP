# uWP
micro WordPress Docker image tuned for low resource environments.

Image is based on centos:6 docker image.

The defaults are 64MB php memory limit, opcode cache 96MB, innodb buffer pool 64MB.

When built the image will expose WordPress on localhost:8080 and phpMyAdmin on localhost:8081.

The latest stable versions are always downloaded.

Auto generated mysql passwords can be found under /root/mysql-root and /root/mysql-uwp.

A database called uwp will be automatically created and owned by the uwp_user.

The virtual hosts are located under files/nginx so you can edit the server_name to match your setup.

On the first run, the jumpstart script will setup the system, exit, and then run the supervisor group uwp.

Supervisord controls the services, so you can see the status of the whole group with

```
# supervisorctl status uwp:*
```

Image setup consists of nginx, php-fpm, and mariadb.

The image exposes two volumes: /var/www/html and /var/lib/mysql.
