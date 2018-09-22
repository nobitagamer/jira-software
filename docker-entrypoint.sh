#!/bin/bash

# check if the `server.xml` file has been changed since the creation of this
# Docker image. If the file has been changed the entrypoint script will not
# perform modifications to the configuration file.
if [ "$(stat -c "%Y" "${JIRA_INSTALL}/conf/server.xml")" -eq "0" ]; then
  if [ -n "${X_PROXY_NAME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyName" --value "${X_PROXY_NAME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_PORT}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "proxyPort" --value "${X_PROXY_PORT}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PROXY_SCHEME}" ]; then
    xmlstarlet ed --inplace --pf --ps --insert '//Connector[@port="8080"]' --type "attr" --name "scheme" --value "${X_PROXY_SCHEME}" "${JIRA_INSTALL}/conf/server.xml"
  fi
  if [ -n "${X_PATH}" ]; then
    xmlstarlet ed --inplace --pf --ps --update '//Context/@path' --value "${X_PATH}" "${JIRA_INSTALL}/conf/server.xml"
  fi
fi

set

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback
# USER_ID=${LOCAL_USER_ID:-9001}
# CONTAINER_USER=jira

# echo "Starting with UID : $USER_ID"
# export HOME=/home/CONTAINER_USER

# addgroup -g $USER_ID $CONTAINER_USER
# adduser -u $USER_ID         \
#         -G $CONTAINER_USER  \
#         -h /$HOME           \
#         -s /bin/bash        \
#         -S $CONTAINER_USER

# Set permissions
# chown -R $JIRA_USER:$JIRA_GROUP ${JIRA_HOME}    &&  \
# chown -R $JIRA_USER:$JIRA_GROUP ${JIRA_INSTALL} &&  \
# chown -R $JIRA_USER:$JIRA_GROUP ${JIRA_SCRIPTS} &&  \
# chown -R $JIRA_USER:$JIRA_GROUP /home/${JIRA_USER}

# exec /usr/local/bin/gosu jira "$@"
# useradd --shell /bin/bash -u $USER_ID -o -c "" -m jira
exec "$@"
