#!/bin/sh

docker run \
  -p 80:5984 \
  -v couchdb-data:/opt/couchdb/data \
  -v couchdb-config:/opt/couchdb/etc/local.d \
  -v couchdb-logs:/opt/couchdb/logs \
  -e COUCHDB_USER=admin \
  -e COUCHDB_PASSWORD=password \
  --restart unless-stopped \
  -d 3237d7fadeeb

    
