#!/bin/bash

originalip=`curl -s ifconfig.me`
{
  # Wait for connect
  ip=$originalip
  while [[ $ip == $originalip ]]
  do
    echo "Waiting for connect... $ip"
    sleep 5
    ip=`curl -s ifconfig.me`
  done

  # Start cron
  service cron start

  # Keep restarting - for when the get_iplayer script is updated
  while [[ `ps aux | grep -v grep | grep /usr/sbin/cron | wc -l` == 1 ]]
  do
    su root -c "/usr/bin/perl /root/get_iplayer.cgi --port 8181 --getiplayer /root/get_iplayer"
  done
} &

