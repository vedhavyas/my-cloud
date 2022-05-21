#!/bin/zsh

/usr/bin/rclone mount hub-crypt: /hub \
  --auto-confirm \
  --allow-other \
# no updates happen on the cloud, so set it to max \
  --dir-cache-time 9999h \
  --poll-interval 0 \
  --log-file /opt/rclone/logs/hub.log \
  --log-level INFO \
  --umask 000 \
  --uid "${PUID}"\
  --gid "${PGID}" \
  --cache-dir=/opt/rclone/cache/hub \
  --vfs-cache-mode full \
  --vfs-cache-max-size 150G \
  --vfs-write-back 5m \
  --vfs-cache-max-age 9999h \
  --vfs-read-ahead 5G \
  --vfs-read-chunk-size 128M \
  --vfs-read-chunk-size-limit 500M \
  --transfers 10 \
  --vfs-used-is-size
