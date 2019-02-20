FROM ubuntu

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install atomicparsley ffmpeg perl libxml-perl libxml-libxml-simple-perl liblwp-protocol-https-perl libmojolicious-perl libcgi-fast-perl wget bash cron psmisc curl jq openvpn unzip ca-certificates -y --no-install-recommends

ENV URL_NORDVPN_API="https://api.nordvpn.com/server" \
    URL_OVPN_FILES="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip" \
    GETIPLAYER_PROFILE="/root/.get_iplayer" \
    COUNTRY="United Kingdom" \
    PROTOCOL="openvpn_udp" \
    MAX_LOAD=70

ADD start.sh /root/start.sh
ADD update.sh /root/update.sh
ADD up.sh /root/up.sh
ADD down.sh /root/down.sh

RUN chmod 755 /root/start.sh
RUN chmod 755 /root/update.sh
RUN chmod 755 /root/up.sh
RUN chmod 755 /root/down.sh

VOLUME /root/.get_iplayer
VOLUME /root/output
VOLUME /root/ovpn

EXPOSE 8181:8181

ENTRYPOINT ["/bin/bash", "/root/start.sh"]
