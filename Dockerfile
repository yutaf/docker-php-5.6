FROM ubuntu:14.04
MAINTAINER yutaf <yutafuji2008@gmail.com>

RUN apt-get update
RUN apt-get install -y \
# binaries for login shell usage (not essential)
  man \
  curl \
# vim
  vim \
# Apache, php \
  make \
  gcc \
  zlib1g-dev \
  libssl-dev \
  libpcre3-dev \
  git \
# php
  perl \
  libxml2-dev \
  libjpeg-dev \
  libpng12-dev \
  libfreetype6-dev \
  libmcrypt-dev \
  libcurl4-openssl-dev \
  libreadline-dev \
  libicu-dev \
  g++ \
# xdebug
  autoconf \
# supervisor
  supervisor

# COPY sources
COPY src src/

#
# Apache
#

# from http://apache.cs.utah.edu//httpd/httpd-2.2.29.tar.gz
RUN cd src && \
  tar xzvf httpd-2.2.29.tar.gz && \
  cd httpd-2.2.29 && \
    ./configure \
      --prefix=/opt/apache2.2.29 \
      --enable-mods-shared=all \
      --enable-proxy \
      --enable-ssl \
      --with-ssl \
      --with-mpm=prefork \
      --with-pcre
# install
RUN cd src/httpd-2.2.29 && \
  make && make install

#
# php
#

# from http://php.net/distributions/php-5.6.11.tar.gz
RUN cd src && \
  tar xzvf php-5.6.11.tar.gz && \
  cd php-5.6.11 && \
  ./configure \
    --prefix=/opt/php-5.6.11 \
    --with-config-file-path=/srv/php \
    --with-apxs2=/opt/apache2.2.29/bin/apxs \
    --with-libdir=lib64 \
    --enable-mbstring \
    --enable-intl \
    --with-icu-dir=/usr \
    --with-gettext=/usr \
    --with-pcre-regex=/usr \
    --with-pcre-dir=/usr \
    --with-readline=/usr \
    --with-libxml-dir=/usr/bin/xml2-config \
    --with-mysql=mysqlnd \
    --with-mysqli=mysqlnd \
    --with-pdo-mysql=mysqlnd \
    --with-zlib=/usr \
    --with-zlib-dir=/usr \
    --with-gd \
    --with-jpeg-dir=/usr \
    --with-png-dir=/usr \
    --with-freetype-dir=/usr \
    --enable-gd-native-ttf \
    --enable-gd-jis-conv \
    --with-openssl=/usr \
# ubuntu only
    --with-libdir=/lib/x86_64-linux-gnu \
    --with-mcrypt=/usr \
    --enable-bcmath \
    --with-curl \
    --enable-exif

# install
RUN cd src/php-5.6.11 && \
  make && make install

#
# xdebug
#

# set php PATH because using phpize for xdebug installation
ENV PATH /opt/php-5.6.11/bin:$PATH

# from http://xdebug.org/files/xdebug-2.3.3.tgz
RUN cd src && \
  tar -xzf xdebug-2.3.3.tgz && \
  cd xdebug-2.3.3 && \
  phpize && \
  ./configure --enable-xdebug && \
  make && \
  make install

# php.ini
COPY templates/php.ini /srv/php/
RUN echo 'zend_extension = "/opt/php-5.6.11/lib/php/extensions/no-debug-non-zts-20131226/xdebug.so"' >> /srv/php/php.ini

# remove sources
RUN rm -rf src

#
# Edit config files
#

# Apache config
RUN sed -i "s/^Listen 80/#&/" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "s/^DocumentRoot/#&/" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "/^<Directory/,/^<\/Directory/s/^/#/" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "s;ScriptAlias /cgi-bin;#&;" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "s;#\(Include conf/extra/httpd-mpm.conf\);\1;" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "s;#\(Include conf/extra/httpd-default.conf\);\1;" /opt/apache2.2.29/conf/httpd.conf && \
# DirectoryIndex; index.html precedes index.php
  sed -i "/^\s*DirectoryIndex/s/$/ index.php/" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "s/\(ServerTokens \)Full/\1Prod/" /opt/apache2.2.29/conf/extra/httpd-default.conf && \
  echo "Include /srv/apache/apache.conf" >> /opt/apache2.2.29/conf/httpd.conf && \
# Change User & Group
  useradd --system --shell /usr/sbin/nologin --user-group --home /dev/null apache; \
  sed -i "s;^\(User \)daemon$;\1apache;" /opt/apache2.2.29/conf/httpd.conf && \
  sed -i "s;^\(Group \)daemon$;\1apache;" /opt/apache2.2.29/conf/httpd.conf

COPY templates/apache.conf /srv/apache/apache.conf
RUN echo 'CustomLog "|/opt/apache2.2.29/bin/rotatelogs /srv/www/logs/access/access.%Y%m%d.log 86400 540" combined' >> /srv/apache/apache.conf && \
  echo 'ErrorLog "|/opt/apache2.2.29/bin/rotatelogs /srv/www/logs/error/error.%Y%m%d.log 86400 540"' >> /srv/apache/apache.conf
#  "mkdir {a,b}" does not work in Ubuntu's /bin/sh, And "RUN <command>" uses "/bin/sh -c".
# Use "RUN ["executable", "param1", "param2"]" instead of "RUN <command>"
RUN ["/bin/bash", "-c", "mkdir -m 777 -p /srv/www/logs/{access,error,app}"]

# make Apache document root directory
COPY www/htdocs/ /srv/www/htdocs/

# supervisor
COPY templates/supervisord.conf /etc/supervisor/conf.d/
RUN echo '[program:apache2]' >> /etc/supervisor/conf.d/supervisord.conf && \
  echo 'command=/opt/apache2.2.29/bin/httpd -DFOREGROUND' >> /etc/supervisor/conf.d/supervisord.conf

# set PATH
RUN sed -i 's;^PATH="[^"]*;&:/opt/php-5.6.11/bin;' /etc/environment && \
# set TERM
  echo export TERM=xterm-256color >> /root/.bashrc && \
# set timezone
  ln -sf /usr/share/zoneinfo/Japan /etc/localtime

# Delete logs except dot files
RUN \
  echo '00 5 1,15 * * find /srv/www/logs -regex ".*/\.[^/]*$" -prune -o -type f -mtime +15 -print -exec rm -f {} \;' > /root/crontab && \
  crontab /root/crontab

# Set up script for running container
COPY scripts/run.sh /usr/local/bin/run.sh
RUN chmod +x /usr/local/bin/run.sh

EXPOSE 80
CMD ["/usr/local/bin/run.sh"]
