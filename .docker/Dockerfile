FROM couchdb:3.5.1

COPY --chown=couchdb:couchdb .docker/livesync.ini /opt/couchdb/etc/local.d/10-livesync.ini
COPY .docker/init.sh /usr/local/bin/livesync-init.sh

EXPOSE 5984
