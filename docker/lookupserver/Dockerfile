FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DBPASSWD=abrakadabra

ADD https://github.com/nextcloud/lookup-server/archive/master.zip /root/lookup-server.zip

COPY lookupserver/entrypoint.sh /usr/sbin/

RUN echo 'mariadb-server mysql-server/root_password password $DBPASSWD' | debconf-set-selections && \
    echo 'mariadb-server mysql-server/root_password_again password $DBPASSWD' | debconf-set-selections && \
    apt-get -y update && apt-get -y full-upgrade && apt-get install -y \
    apache2 \
    libapache2-mod-php \
    php \
    php-mysql \
    mariadb-server \
    mariadb-client \
    cron \
    composer \
    unzip && \
    rm -rf /var/lib/apt/lists/*


RUN cd /root/ && \
    unzip lookup-server.zip && \
    rm /var/www/html/index.html && \
    composer u --working-dir lookup-server-master/server/ --ignore-platform-req=ext-* && \
    mv lookup-server-master/server/* /var/www/html/ && \
    cp lookup-server-master/server/.htaccess /var/www/html/ && \
    mv lookup-server-master/mysql.dmp /root/ && \
    rm lookup-server.zip && \
    rm -Rf lookup-server-master

COPY lookupserver/config.php /var/www/html/config
COPY lookupserver/lookup.conf /etc/apache2/conf-available/

RUN a2enmod rewrite && \
    a2enconf lookup && \
    chown -R www-data /var/www/html && \
    chmod +x /usr/sbin/entrypoint.sh

#RUN echo "*/10 * * * * www-data    php -f /var/www/html/replicationcron.php" > /etc/cron.d/lookup-server
#RUN echo "*/10 * * * * www-data    php -f /var/www/html/verifycron.php" > /etc/cron.d/lookup-server

VOLUME [ "/var/lib/mysql" ]

EXPOSE 80

ENTRYPOINT /usr/sbin/entrypoint.sh
