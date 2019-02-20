#!/bin/bash

# Stop the cron jobs
service cron stop

# Stop the web portal
killall -q -9 perl || echo -e '\c'
