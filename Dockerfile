FROM ubuntu

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install atomicparsley ffmpeg perl libxml-perl libxml-libxml-simple-perl liblwp-protocol-https-perl libmojolicious-perl libcgi-fast-perl wget bash cron psmisc -y --no-install-recommends

ENV GETIPLAYER_PROFILE="/root/.get_iplayer"

ADD start.sh /root/start.sh
ADD update.sh /root/update.sh

RUN chmod 755 /root/start.sh
RUN chmod 755 /root/update.sh

VOLUME /root/.get_iplayer
VOLUME /root/output

EXPOSE 8181:8181

ENTRYPOINT ["/bin/bash", "/root/start.sh"]
