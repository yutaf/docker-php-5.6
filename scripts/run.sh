#!/usr/bin/env bash

#TODO set TERM in bashrc or something
export TERM=xterm-256color

# php session
mkdir -m 777 -p /srv/php/session
echo "tmpfs /srv/php/session tmpfs size=32m,mode=700,uid=daemon,gid=daemon 0 0" >> /etc/fstab
mount /srv/php/session # need docker run "--cap-add=SYS_ADMIN" option

# php upload_tmp_dir
mkdir -m 777 -p /srv/php/upload_tmp_dir

#
# Run container foreground
#

# supervisor
/usr/bin/supervisord
