#!/usr/bin/env bash
set -Eeuo pipefail
sudo -n /usr/sbin/nginx -t -c /etc/bytedepth/production-green-public-nginx.conf
sudo -n /usr/bin/systemctl reload bytedepth-production-green-public-nginx.service
