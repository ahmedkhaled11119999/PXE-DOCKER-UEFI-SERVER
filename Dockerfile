FROM ubuntu:20.04

LABEL maintainer="ahmed.khaled@e-vastel.com"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata
RUN apt-get update && apt-get install -y apache2 tftpd-hpa gettext-base pxelinux isc-dhcp-server
RUN mkdir -p /ks/ /images/ /packages/ /srv/tftp/

COPY tftp/. /srv/tftp/
COPY dhcpd.conf.tmp /etc/dhcp/
COPY ks-server.conf.tmp /etc/apache2/sites-available/
COPY user-data /ks/
COPY pxe-config.sh /

WORKDIR /

RUN chmod +x pxe-config.sh


ENTRYPOINT ["bash","-c","sleep 10 && ./pxe-config.sh && /bin/bash"]
