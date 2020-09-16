FROM frolvlad/alpine-java:jdk8-slim
# FROM sgrio/java:jdk_11
# FROM debian:stretch-slim

# Permissions, set the linux user id and group id
ARG CONTAINER_UID=2001
ARG CONTAINER_GID=2001

# DO NOT use 7.12.2 because of this bug https://confluence.atlassian.com/jirasoftware/jira-software-7-12-x-release-notes-953676636.html
ARG JIRA_VERSION=8.5.8
ARG GOSU_VERSION=1.11
ARG DOCKERIZE_VERSION=v0.6.1
ARG MYSQL_DRIVER_VERSION=5.1.48
ARG POSTGRESQL_DRIVER_VERSION=42.2.6
# ARG JIRA_DOWNLOAD_URI=https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-core-${JIRA_VERSION}.tar.gz
ARG JIRA_DOWNLOAD_URI=https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}.tar.gz

# Language Settings
ARG LANG_LANGUAGE=en
ARG LANG_COUNTRY=US

# Configuration variables.
ENV JIRA_HOME     /var/atlassian/jira       
ENV JIRA_INSTALL  /opt/atlassian/jira
ENV JIRA_SCRIPTS  /usr/local/share/atlassian

ENV CONTAINER_USER=jira                       \
    CONTAINER_GROUP=jira                      \
    JIRA_CONTEXT_PATH=ROOT                    \
    JIRA_HOME=/var/atlassian/jira             \
    JIRA_INSTALL=/opt/atlassian/jira          \
    JIRA_SCRIPTS=/usr/local/share/atlassian   \
    LANG=${LANG_LANGUAGE}_${LANG_COUNTRY}.UTF-8 \
    LC_ALL=C

# Setup Jira User & Group + directories
RUN set -x \
	&& addgroup -g $CONTAINER_GID $CONTAINER_GROUP \
	&& adduser -u $CONTAINER_UID                   \
		-h /home/$CONTAINER_USER                   \
		-S -s /bin/bash                            \
		-G $CONTAINER_GROUP                        \
		$CONTAINER_USER                            \
    && mkdir -p "${JIRA_HOME}" \
                "${JIRA_HOME}/caches/index" \
                "${JIRA_INSTALL}/conf/Catalina"

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

# Install build deps & required binaries
RUN apk update \
    && apk upgrade \
    && apk add --no-cache --virtual .build-deps \
        curl \
        tar 

# JIRA install/setup. Order of operations:
# 1. JIRA assets + install
# 2. Postgres Driver
# 3. MySQL Driver
# 4. Permissions
# 5. Update configurations
RUN apk add --no-cache \
        bash \
        fontconfig \
        ttf-dejavu \
        xmlstarlet tini openssl ca-certificates \
    && update-ca-certificates 2>/dev/null || true \
    && curl -Ls "${JIRA_DOWNLOAD_URI}" \
        | tar -xz --directory "${JIRA_INSTALL}" \
            --strip-components=1 --no-same-owner \
    && cd "${JIRA_INSTALL}/lib" \
    && rm -f "${JIRA_INSTALL}/lib/postgresql-9.*" \
    && curl -Os "https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar" \
    && curl -Ls "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz" \
        | tar -xz --directory "${JIRA_INSTALL}/lib" \
            --strip-components=1 --no-same-owner \
            "mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar" \
    && chmod -R 700 "${JIRA_HOME}" \
                    "${JIRA_INSTALL}/conf" \
                    "${JIRA_INSTALL}/temp" \
                    "${JIRA_INSTALL}/logs" \
                    "${JIRA_INSTALL}/work" \
    && chown -R "${CONTAINER_USER}":"${CONTAINER_GROUP}" "${JIRA_HOME}" \
                                         "${JIRA_INSTALL}/conf" \
                                         "${JIRA_INSTALL}/temp" \
                                         "${JIRA_INSTALL}/logs" \
                                         "${JIRA_INSTALL}/work" \
    && sed --in-place "s/java version/openjdk version/g" "${JIRA_INSTALL}/bin/check-java.sh" \
    && echo -e "\njira.home=${JIRA_HOME}" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
    && touch -d "@0" "${JIRA_INSTALL}/conf/server.xml" \
    # Install dockerize
    && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    # Clean caches and tmps
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*           \
    && rm -rf /var/log/*

# Remove build dependencies
RUN apk del .build-deps

# RUN apk update \
#     && apk upgrade \
#     && apk add --no-cache curl xmlstarlet bash ttf-dejavu tini openssl ca-certificates \
#     && update-ca-certificates 2>/dev/null || true \
#     && mkdir -p                "${JIRA_HOME}" \
#     && mkdir -p                "${JIRA_HOME}/caches/indexes" \
#     && mkdir -p                "${JIRA_INSTALL}/conf/Catalina" \
#     && curl -Ls                "https://www.atlassian.com/software/jira/downloads/binary/atlassian-jira-software-${JIRA_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}" --strip-components=1 --no-same-owner \
#     && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_DRIVER_VERSION}.tar.gz" | tar -xz --directory "${JIRA_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-${MYSQL_DRIVER_VERSION}/mysql-connector-java-${MYSQL_DRIVER_VERSION}-bin.jar" \
#     && rm -f                   "${JIRA_INSTALL}/lib/postgresql-${REMOVE_POSTGRESQL_DRIVER_VERSION}.jar" \
#     && curl -Ls                "https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar" -o "${JIRA_INSTALL}/lib/postgresql-${POSTGRESQL_DRIVER_VERSION}.jar" \
#     && echo -e                 "\njira.home=$JIRA_HOME" >> "${JIRA_INSTALL}/atlassian-jira/WEB-INF/classes/jira-application.properties" \
#     && touch -d "@0"           "${JIRA_INSTALL}/conf/server.xml" \
    # # Install dockerize version v0.6.1
    # && wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    # && tar -C /usr/local/bin -xzvf dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    # && rm dockerize-alpine-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
    # # Clean caches and tmps
    # && rm -rf /var/cache/apk/* \
    # && rm -rf /tmp/*           \
    # && rm -rf /var/log/*

ENV JVM_MINIMUM_MEMORY=768m \
    JVM_MAXIMUM_MEMORY=1280m

COPY imagescripts ${JIRA_SCRIPTS}

RUN set -x \
    && sed -i 's/JVM_MINIMUM_MEMORY="384m"/JVM_MINIMUM_MEMORY="${JVM_MINIMUM_MEMORY}"/g' /opt/atlassian/jira/bin/setenv.sh \
	&& sed -i 's/JVM_MAXIMUM_MEMORY="2048m"/JVM_MAXIMUM_MEMORY="${JVM_MAXIMUM_MEMORY}"/g' /opt/atlassian/jira/bin/setenv.sh \
    && /bin/bash ${JIRA_SCRIPTS}/patch.sh *.jar ${JIRA_INSTALL}/atlassian-jira/WEB-INF/

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
# USER daemon:daemon

# Switch from root
USER "${CONTAINER_USER}":"${CONTAINER_GROUP}"

# 8080: Expose default HTTP connector port.
# 9093: Balsamiq Real-Time Collaboration Service

EXPOSE 8080 9093

# Persist the log and home dirs + JRE security folder (cacerts)
# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${JIRA_INSTALL}/logs", "${JIRA_INSTALL}/conf", "${JIRA_HOME}", "${JAVA_HOME}/jre/lib/security/"]

# Set the default working directory as the installation directory.
WORKDIR ${JIRA_HOME}

ENTRYPOINT ["/sbin/tini","--","/usr/local/share/atlassian/docker-entrypoint.sh"]

# Run Atlassian JIRA as a foreground process by default.
CMD ["jira", "-Datlassian.plugins.enable.wait=300"]

# Metadata
# Image Build Date By Buildsystem
ARG BUILD_DATE=undefined
ARG VCS_REF
ARG VERSION
LABEL maintainer="Nguyen Khac Trieu <trieunk@yahoo.com>" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.name="JIRA - Alpine" \
    org.label-schema.description="Provides a Docker image for JIRA on Alpine Linux." \
    org.label-schema.url="https://trieunk.info/" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/nobitagamer/jira-software" \
    org.label-schema.vendor="Trieunk" \
    org.label-schema.version=$VERSION \
    org.label-schema.schema-version="1.0"