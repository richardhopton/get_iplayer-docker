#!/bin/bash

# Check if we have get_iplayer
if [[ ! -f /root/get_iplayer.cgi ]]
then
  /root/update.sh start
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
fi

base_dir="/root"
ovpn_dir="$base_dir/ovpn"
auth_file="$base_dir/auth"

if [ `ls -A $ovpn_dir | wc -l` -eq 0 ]
then
    echo "Server configs not found. Download configs from NordVPN"
    curl -s $URL_OVPN_FILES -o /tmp/ovpn.zip
    unzip -q /tmp/ovpn.zip -d /tmp/ovpn
    mv /tmp/ovpn/*/*.ovpn $ovpn_dir
    rm -rf /tmp/*
fi

# Use api.nordvpn.com
servers=`curl -s $URL_NORDVPN_API`
servers=`echo $servers | jq -c '.[] | select(.features.openvpn_udp == true)' &&\
         echo $servers | jq -c '.[] | select(.features.openvpn_tcp == true)'`
servers=`echo $servers | jq -s -a -c 'unique'`
pool_length=`echo $servers | jq 'length'`
echo "OpenVPN servers in pool: $pool_length"
servers=`echo $servers | jq -c '.[]'`

IFS=';'

if [[ !($pool_length -eq 0) ]]; then
    if [[ -z "${COUNTRY}" ]]; then
        echo "Country not set, skip filtering"
    else
        echo "Filter pool by country: $COUNTRY"
        read -ra countries <<< "$COUNTRY"
        for country in "${countries[@]}"; do
            filtered="$filtered"`echo $servers | jq -c 'select(.country == "'$country'")'`
        done
        filtered=`echo $filtered | jq -s -a -c 'unique'`
        pool_length=`echo $filtered | jq 'length'`
        echo "Servers in filtered pool: $pool_length"
        servers=`echo $filtered | jq -c '.[]'`
    fi
fi

if [[ !($pool_length -eq 0) ]]; then
    if [[ -z "${CATEGORY}" ]]; then
        echo "Category not set, skip filtering"
    else
        echo "Filter pool by category: $CATEGORY"
        read -ra categories <<< "$CATEGORY"
        filtered="$servers"
        for category in "${categories[@]}"; do
            filtered=`echo $filtered | jq -c 'select(.categories[].name == "'$category'")'`
        done
        filtered=`echo $filtered | jq -s -a -c 'unique'`
        pool_length=`echo $filtered | jq 'length'`
        echo "Servers in filtered pool: $pool_length"
        servers=`echo $filtered | jq -c '.[]'`
    fi
fi

if [[ !($pool_length -eq 0) ]]; then
    if [[ -z "${PROTOCOL}" ]]; then
        echo "Protocol not set, skip filtering"
    else
        echo "Filter pool by protocol: $PROTOCOL"
        filtered=`echo $servers | jq -c 'select(.features.'$PROTOCOL' == true)' | jq -s -a -c 'unique'`
        pool_length=`echo $filtered | jq 'length'`
        echo "Servers in filtered pool: $pool_length"
        servers=`echo $filtered | jq -c '.[]'`
    fi
fi

if [[ !($pool_length -eq 0) ]]; then
    echo "Filter pool by load, less than $MAX_LOAD%"
    servers=`echo $servers | jq -c 'select(.load <= '$MAX_LOAD')'`
    pool_length=`echo $servers | jq -s -a -c 'unique' | jq 'length'`
    echo "Servers in filtered pool: $pool_length"
    servers=`echo $servers | jq -s -c 'sort_by(.load)[]'`
fi

if [[ !($pool_length -eq 0) ]]; then
    echo "--- Top 20 servers in filtered pool ---"
    echo `echo $servers | jq -r '"\(.domain) \(.load)%"' | head -n 20`
    echo "---------------------------------------"
fi

servers=`echo $servers | jq -r '.domain'`
IFS=$'\n'
read -ra filtered <<< "$servers"

for server in "${filtered[@]}"; do
    if [[ -z "${PROTOCOL}" ]] || [[ "${PROTOCOL}" == "openvpn_udp" ]]; then
        config_file="${ovpn_dir}/${server}.udp.ovpn"
        if [ -r "$config_file" ]; then
            config="$config_file"
            break
        else
            echo "UDP config for server $server not found"
        fi
    fi
    if [[ -z "${PROTOCOL}" ]] || [[ "${PROTOCOL}" == "openvpn_tcp" ]]; then
        config_file="${ovpn_dir}/${server}.tcp.ovpn"
        if [ -r "$config_file" ]; then
            config="$config_file"
            break
        else
            echo "TCP config for server $server not found"
        fi
    fi
done

if [ -z $config ]; then
    echo "List of recommended servers is empty or configs not found. Select random server from available configs."
    config="${ovpn_dir}/`ls ${ovpn_dir} | shuf -n 1`"
fi

# Create auth_file
echo "$USER" > $auth_file
echo "$PASS" >> $auth_file
chmod 0600 $auth_file

openvpn --cd $base_dir --config $config \
    --auth-user-pass $auth_file --auth-nocache \
    --script-security 2 --up $base_dir/up.sh --down $base_dir/down.sh
