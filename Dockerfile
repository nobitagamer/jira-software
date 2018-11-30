FROM frolvlad/alpine-oraclejdk8
# FROM debian:stretch-slim
MAINTAINER Nguyen Khac Trieu <trieunk@yahoo.com>

# Permissions, set the linux user id and group id
# ARG CONTAINER_UID=1000
# ARG CONTAINER_GID=1000

# Image Build Date By Buildsystem
ARG BUILD_DATE=undefined

# Language Settings
ARG LANG_LANGUAGE=en
ARG LANG_COUNTRY=US

# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira       
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV JIRA_SCRIPTS  /usr/local/share/atlassian

# DO NOT use 7.12.2 because of this bug https://confluence.atlassian.com/jirasoftware/jira-software-7-12-x-release-notes-953676636.html
ENV JIRA_VERSION        7.13.0
ENV GOSU_VERSION        1.10
ENV DOCKERIZE_VERSION   v0.6.1

# ENV JIRA_USER=jira                            \
#     JIRA_GROUP=jira                           \
#     JIRA_CONTEXT_PATH=ROOT                    \
#     JIRA_HOME=/var/atlassian/jira             \
#     JIRA_INSTALL=/opt/atlassian/jira          \
#     JIRA_SCRIPTS=/usr/local/share/atlassian   \
#     MYSQL_DRIVER_VERSION=5.1.38               \
#     POSTGRESQL_DRIVER_VERSION=42.2.1
#     # POSTGRESQL_DRIVER_VERSION=9.4.1212

# ENV JAVA_HOME=$JIRA_INSTALL/jre

# ENV PATH=$PATH:$JAVA_HOME/bin \
#     LANG=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8

# See https://github.com/tianon/gosu/blob/master/INSTALL.md
# RUN set -ex; \
# 	\
# 	apk add --no-cache --virtual .gosu-deps \
# 		dpkg \
# 		gnupg \
# 		openssl \
# 	; \
# 	\
# 	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
# 	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
# 	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
# 	\
# 	# verify the signature
# 	export GNUPGHOME="$(mktemp -d)"; \
# 	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
# 	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
# 	rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc; \
# 	\
# 	chmod +x /usr/local/bin/gosu; \
# 	# verify that the binary works
# 	gosu nobody true; \
# 	\
# 	apk del .gosu-deps

# RUN set -x \
# 	# Add user
#     && export CONTAINER_USER=jira                  \
# 	&& export CONTAINER_UID=1000                   \
# 	&& export CONTAINER_GROUP=jira                 \
# 	&& export CONTAINER_GID=1000                   \
# 	&& addgroup -g $CONTAINER_GID $CONTAINER_GROUP \
# 	&& adduser -u $CONTAINER_UID                   \
# 		-G $CONTAINER_GROUP                        \
# 		-h /home/$CONTAINER_USER                   \
# 		-s /bin/bash                               \
# 		-S $CONTAINER_USER

RUN apk update \
    && apk upgrade \
    && apk add --no-cache curl xmlstarlet bash ttf-dejavu tini openssl ca-certificates \
    && update-ca-certificates 2>/dev/null || true \
    && mkdir -p                "${JIRA_HOME}" \
    && mkdir -p                "${JIRA_HOME}/caches/indexes" \
    && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
    && curl -Ls                "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.38.tar.gz" | tar -xz --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.38/mysql-connector-java-5.1.38-bin.jar" \
    && rm -f                   "${JIRA_INSTALL}/lib/postgresql-9.1-903.jdbc4-atlassian-hosted.jar" \
    && curl -Ls                "https://jdbc.postgresql.org/download/postgresql-42.2.1.jar" -o "${JIRA_INSTALL}/lib/postgresql-42.2.1.jar" \
    && echo -e                 "\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0"           "${JIRA_INSTALL}/conf/server.xml" \
    # Install dockerize version v0.6.1
    && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    # Clean caches and tmps
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*           \
    && rm -rf /var/log/*

# WORKDIR /root/

# RUN apt-get update \
# 	&& apt-get install -y wget fastjar \
# 	&& wget https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-"${JIRA_VERSION}"-x64.bin \
# 	&& chmod 700 atlassian-jira-software-"${JIRA_VERSION}"-x64.bin

# ADD response.varfile /opt/atlassian/jira/.install4j/response.varfile

# COPY ./com ./com

# RUN bash +x /root/atlassian-jira-software-"${JIRA_VERSION}"-x64.bin -q -varfile /opt/atlassian/jira/.install4j/response.varfile \
# 	&& rm -f atlassian-jira-software-"${JIRA_VERSION}"-x64.bin \
# 	&& jar uf /opt/atlassian/jira/atlassian-jira/WEB-INF/lib/atlassian-extras-3.2.jar com/atlassian/extras/decoder/v2/Version2LicenseDecoder.class \
# 	&& rm -rf ./com

ENV JVM_MINIMUM_MEMORY=768m \
    JVM_MAXIMUM_MEMORY=1280m

COPY imagescripts ${JIRA_SCRIPTS}

RUN set -x \
    && sed -i 's/JVM_MINIMUM_MEMORY="384m"/JVM_MINIMUM_MEMORY="${JVM_MINIMUM_MEMORY}"/g' /opt/atlassian/jira/bin/setenv.sh \
	&& sed -i 's/JVM_MAXIMUM_MEMORY="768m"/JVM_MAXIMUM_MEMORY="${JVM_MAXIMUM_MEMORY}"/g' /opt/atlassian/jira/bin/setenv.sh \
    && /bin/bash ${JIRA_SCRIPTS}/patch.sh *.jar ${JIRA_INSTALL}/atlassian-jira/WEB-INF/

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
# USER daemon:daemon
# USER jira

# 8080: Expose default HTTP connector port.
# 9093: Balsamiq Real-Time Collaboration Service

EXPOSE 8080 9093

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["/var/atlassian/jira", "/opt/atlassian/jira/logs"]

# Set the default working directory as the installation directory.
WORKDIR ${JIRA_HOME}

ENTRYPOINT ["/sbin/tini","--","/usr/local/share/atlassian/docker-entrypoint.sh"]

# Run Atlassian JIRA as a foreground process by default.
CMD ["jira", "-Datlassian.plugins.enable.wait=300"]
