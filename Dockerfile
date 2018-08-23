# Licensed under the Apache License, Version 2.1 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

FROM arm64v8/ubuntu:16.04
LABEL maintainer="con.sume.org@gmail.com"

# Add CouchDB user account
RUN groupadd -r couchdb && useradd -d /opt/couchdb -g couchdb couchdb

RUN apt-get update -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    erlang-nox \
    erlang-reltool \
    haproxy \
    libicu-dev \
    openssl \
  && rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root and tini for signal handling
# see https://github.com/apache/couchdb-docker/pull/28#discussion_r141112407
ENV GOSU_VERSION 1.10
ENV TINI_VERSION 0.16.1
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends wget; \
	rm -rf /var/lib/apt/lists/*; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	\
# install gosu
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$dpkgArch"; \
	chmod +x /usr/local/bin/gosu; \
	\
# check if tini exists
### If you are using Docker 1.13 or greater, Tini is included in Docker itself. 
### This includes all versions of Docker CE. 
### To enable Tini, just pass the --init flag to docker run.

        if ! type "tini" > /dev/null; then \
        \
# if not then install tini
	wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch"; \
	chmod +x /usr/local/bin/tini; \
	tini --version; \
	\
	fi; \
	apt-get purge -y --auto-remove wget


ENV COUCHDB_VERSION 2.2.0

# Download dev dependencies
RUN buildDeps=' \
    apt-transport-https \
    gcc \
    g++ \
    git \
    erlang-dev \
    libcurl4-openssl-dev \
    libicu-dev \
    make \
  ' \
 && apt-get update -y -qq && apt-get install -y --no-install-recommends $buildDeps \
 # Acquire CouchDB source code
 && cd /usr/src && mkdir couchdb \
 && curl -fSL https://dist.apache.org/repos/dist/release/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz -o apache-couchdb-$COUCHDB_VERSION.tar.gz \
 
 ### instead of failing gpg maybe use sha512 check?
 && curl -fSL https://dist.apache.org/repos/dist/release/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz.sha512 -o apache-couchdb-$COUCHDB_VERSION.tar.gz.sha512 \
 && sha512sum --check apache-couchdb-$COUCHDB_VERSION.tar.gz.sha512 \
 
 && tar -xzf apache-couchdb-$COUCHDB_VERSION.tar.gz -C couchdb --strip-components=1
 
 ### install patched rebar upfront...
RUN set -x \ 
  && git clone --depth 1 --branch 2.6.0-couchdb https://github.com/kulturpessimist/couchdb-rebar.git /usr/src/rebar \
  && make -C /usr/src/rebar \
  && rm -rf /usr/src/couchdb/bin/rebar \
  && mv /usr/src/rebar/rebar /usr/src/couchdb/bin/rebar \
  && make -C /usr/src/rebar clean
 ###

### install special mozjs 1.8.5 ... with help from https://github.com/lag-linaro/couchdb-arm64/blob/master/Dockerfile
RUN buildDebDeps=' \
    autotools-dev \
    devscripts \
    debhelper \
    build-essential \
    libffi-dev \
    libnspr4-dev \
    zip \
    pkg-kde-tools \
    python \
    pkg-config \
  ' \
  && set -x \
  && apt-get install -y --no-install-recommends $buildDebDeps \
	&& cd /usr/src \
	&& git clone https://github.com/apache/couchdb-pkg.git \
	&& cd couchdb-pkg \
	&& make couch-js-debs \
	&& dpkg -i js/couch-libmozjs185-*.deb \
	&& make build-couch xenial PLATFORM=xenial 

 # Build the release and install into /opt --disable-docs
 RUN cd /usr/src/couchdb \
  && ./configure \
  && make \
  && make release \
  && mv /usr/src/couchdb/rel/couchdb /opt/ \
  # Cleanup build detritus
  && apt-get purge -y --auto-remove $buildDeps \
  && rm -rf /var/lib/apt/lists/* /usr/src/couchdb* \
  && mkdir /opt/couchdb/data \
  && chown -R couchdb:couchdb /opt/couchdb

# Add configuration
COPY local.ini /opt/couchdb/etc/local.d/
COPY vm.args /opt/couchdb/etc/

COPY ./docker-entrypoint.sh /

# Setup directories and permissions
RUN chown -R couchdb:couchdb /opt/couchdb/etc/local.d/ /opt/couchdb/etc/vm.args

WORKDIR /opt/couchdb
EXPOSE 5984 4369 9100
VOLUME ["/opt/couchdb/data"]

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
CMD ["/opt/couchdb/bin/couchdb"]
