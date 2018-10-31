#!/bin/sh

docker run \
    -d \
    -p 5984:5984 \
    --volume /opt/couchdb/data:/opt/couchdb/data \
    --volume /opt/couchdb/config:/opt/couchdb/etc/local.d/ \
    --volume /opt/couchdb/logs:/opt/couchdb/logs/ \
    --name arm-couch \
    --env COUCHDB_USER=admin \
    --env COUCHDB_PASSWORD=password
