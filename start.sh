#!/bin/bash

# Check if we have get_iplayer
if [[ ! -f /root/get_iplayer.cgi ]]
then
  /root/update.sh start
fi

if [[ ! -f /root/get_iplayer ]]
then  # pause for checking things out...
  echo err1 - Error occurred, pausing for 9999 seconds for investigation
  sleep 9999
fi

# Set some nice defaults
if [[ ! -f /root/.get_iplayer/options ]]
then
  echo No options file found, adding some nice defaults...
  /root/get_iplayer --prefs-add --whitespace
  /root/get_iplayer --prefs-add --nopurge
  /root/get_iplayer --prefs-add --output="/root/output/"
  
  echo Removing non-standard download location from existing PVR files...
  # so downloads don't get saved in the container
  sed -i '/^output/d' /root/.get_iplayer/pvr/*
fi

if [[ -f /root/get_iplayer.cgi ]]
then
    echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" > /root/cron.tab && \
    echo "@hourly /root/get_iplayer --refresh > /proc/1/fd/1 2>&1" >> /root/cron.tab && \
    echo "@hourly /root/get_iplayer --pvr > /proc/1/fd/1 2>&1" >> /root/cron.tab && \
    echo "@daily /root/update.sh > /proc/1/fd/1 2>&1" >> /root/cron.tab && \
    crontab -u root /root/cron.tab && \
    rm -f /root/cron.tab

  # Start cron
  service cron start
  
  # Keep restarting - for when the get_iplayer script is updated
  while true
  do
    su - root -c "/usr/bin/perl /root/get_iplayer.cgi --port 8181 --getiplayer /root/get_iplayer"
  done 
else
  echo err2 - Error occurred, pausing for 9999 seconds for investigation
  sleep 9999 # when testing, keep container up long enough to check stuff out
fi

