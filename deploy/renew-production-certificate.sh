#!/usr/bin/env bash
set -Eeuo pipefail
sudo -n /usr/sbin/nginx -t -c /etc/bytedepth/production-public-nginx.conf
sudo -n /usr/bin/systemctl reload bytedepth-production-public-nginx.service
