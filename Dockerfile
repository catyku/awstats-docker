FROM centos:7
MAINTAINER catyku

RUN yum update -y && yum upgrade -y 

RUN yum -y install epel-release && yum -y update && yum -y upgrade && \
    yum -y install awstats httpd && \
    yum clean all

RUN mkdir -p /opt/GeoIP && \
    curl -L https://mirrors-cdn.liferay.com/geolite.maxmind.com/download/geoip/database/GeoIP.dat.gz \
        | gunzip -c - > /opt/GeoIP/GeoIP.dat && \
    curl -L https://mirrors-cdn.liferay.com/geolite.maxmind.com/download/geoip/database/GeoLiteCityv6.dat.gz \
        | gunzip -c - > /opt/GeoIP/GeoLiteCity.dat
RUN useradd -M -d /var/lib/awstats awstats && \
    chown awstats:awstats /var/lib/awstats /etc/awstats /run/httpd && \
    bash -O extglob -c 'rm /etc/awstats/!(awstats.model.conf)'

# Log to stdout/stderr, copied from
# https://github.com/docker-library/httpd/blob/0e4a0b59e1f4e2a5a14ca197516beb2d4df1ffb8/2.4/alpine/Dockerfile#L78
RUN \
    sed -i "s/Require local/Require all granted/" /etc/httpd/conf.d/awstats.conf && \
    sed -ri \
        -e 's!^(\s*CustomLog)\s+\S+!\1 /proc/self/fd/1!g' \
        -e 's!^(\s*ErrorLog)\s+\S+!\1 /proc/self/fd/2!g' \
        -e 's!^(\s*Listen)\s+\S+!\1 8080!g' \
        /etc/httpd/conf/httpd.conf && \
    echo "RedirectMatch ^/$ /awstats/awstats.pl?config=localhost" > /etc/httpd/conf.d/welcome.conf
COPY entrypoint.pl /

USER awstats

RUN mkdir -p /tmp/data

EXPOSE 8080

# Awstats database
VOLUME ["/var/lib/awstats/"]

ENTRYPOINT ["/entrypoint.pl"]
