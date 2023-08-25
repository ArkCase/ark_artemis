###########################################################################################################
#
# How to build:
#
# docker build -t arkcase/artemis:latest .
#
# How to run: (Helm)
#
# helm repo add arkcase https://arkcase.github.io/ark_helm_charts/
# helm install ark-artemis arkcase/ark-artemis
# helm uninstall ark-artemis
#
# How to run: (Docker)
#
# docker run --name ark_artemis -p 8161:8161  -d arkcase/artemis:latest 
# docker exec -it ark_artemis /bin/bash
# docker stop ark_artemis
# docker rm ark_artemis
#
# How to run: (Kubernetes)
#
# kubectl create -f pod_ark_artemis.yaml
# kubectl --namespace default port-forward artemis 8080:8161 --address='0.0.0.0'
# kubectl exec -it pod/artemis -- bash
# kubectl delete -f pod_ark_artemis.yaml
#
###########################################################################################################

ARG PUBLIC_REGISTRY="public.ecr.aws"
ARG BASE_REPO="arkcase/base"
ARG BASE_TAG="8.8-02"
ARG ARCH="amd64"
ARG OS="linux"
ARG VER="2.30.0"
ARG BLD="04"
ARG PKG="artemis"
ARG SRC="https://archive.apache.org/dist/activemq/activemq-artemis/${VER}/apache-artemis-${VER}-bin.tar.gz"
ARG JMX_VER="0.17.0"
ARG JMX_SRC="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_VER}/jmx_prometheus_javaagent-${JMX_VER}.jar"

FROM "${PUBLIC_REGISTRY}/${BASE_REPO}:${BASE_TAG}"

ARG ARCH
ARG OS
ARG VER
ARG BLD
ARG PKG
ARG APP_UID="1998"
ARG APP_GID="${APP_UID}"
ARG APP_USER="${PKG}"
ARG APP_GROUP="${APP_USER}"
ARG BASE_DIR="/app"
ARG HOME_DIR="${BASE_DIR}/${PKG}"
ARG CONF_DIR="${BASE_DIR}/conf"
ARG DATA_DIR="${BASE_DIR}/data"
ARG LOGS_DIR="${BASE_DIR}/logs"
ARG TEMP_DIR="${BASE_DIR}/temp"
ARG SRC
ARG JMX_SRC

#
# Basic Parameters
#

LABEL ORG="Armedia LLC"
LABEL MAINTAINER="Armedia Devops Team <devops@armedia.com>"
LABEL APP="Artemis"
LABEL VERSION="${VER}"

# Environment variables: tarball stuff
ENV JMX_PROMETHEUS_AGENT_JAR="jmx_prometheus_javaagent-${JMX_VER}.jar"
# Environment variables: ActiveMQ directories
ENV BASE_DIR="${BASE_DIR}"
ENV HOME_DIR="${HOME_DIR}"
ENV CONF_DIR="${CONF_DIR}"
ENV DATA_DIR="${DATA_DIR}"
ENV LOGS_DIR="${LOGS_DIR}"
ENV TEMP_DIR="${TEMP_DIR}"

ENV ARTEMIS_HOME="${HOME_DIR}"
ENV ARTEMIS_BASE="${HOME_DIR}"
ENV ARTEMIS_CONF="${CONF_DIR}"
ENV ARTEMIS_DATA="${DATA_DIR}"
ENV ARTEMIS_TMP="${TEMP_DIR}"

# Environment variables: system stuff
ENV APP_UID="${APP_UID}"
ENV APP_GID="${APP_GID}"
ENV APP_USER="${APP_USER}"
ENV APP_GROUP="${APP_GROUP}"

# Environment variables: Java stuff
ENV JAVA_HOME="/usr/lib/jvm/jre-11-openjdk"
ENV USER="${APP_USER}"

WORKDIR "${BASE_DIR}"

ENV JMX_AGENT_JAR="${HOME_DIR}/jmx-prometheus-agent.jar"
ENV JMX_AGENT_CONF="${CONF_DIR}/jmx-prometheus-agent.yaml"

# Activate the Prometheus JMX exporter
ENV ARTEMIS_SUNJMX_START="-javaagent:${JMX_AGENT_JAR}=9100:${JMX_AGENT_CONF}"
ENV PATH="${HOME_DIR}/bin:${PATH}"

#
# Update local packages and install required packages
#
RUN yum -y install \
        java-11-openjdk-devel \
        libaio \
        sudo \
        xmlstarlet \
    && \
    yum -y clean all && \
    curl -L -o "/artemis.tar.gz" "${SRC}" && \
    mkdir -p "${HOME_DIR}" "${CONF_DIR}" "${DATA_DIR}" "${LOGS_DIR}" "${TEMP_DIR}" && \
    tar -C "${HOME_DIR}" --strip-components=1 -xzvf "/artemis.tar.gz" && \
    rm -rf "${HOME_DIR}/examples" "/artemis.tar.gz" && \
    curl -L -o "${JMX_AGENT_JAR}" "${JMX_SRC}"

#
# Install the remaining files
#
COPY jmx-prometheus-agent.yaml "${JMX_AGENT_CONF}"
COPY --chown=root:root entrypoint /

#
# Create the required user/group
#
RUN groupadd --gid "${APP_GID}" "${APP_GROUP}" && \
    useradd  --uid "${APP_UID}" --gid "${APP_GROUP}" --groups "${ACM_GROUP}" --create-home --home-dir "${HOME_DIR}" "${APP_USER}"

COPY broker "${HOME_DIR}/bin/broker"

RUN rm -rf /tmp/* && \
    chown -R "${APP_USER}:${APP_GROUP}" "${BASE_DIR}" && \
    chmod -R "u=rwX,g=rX,o=" "${BASE_DIR}" && \
    chmod 0755 /entrypoint

#
# Launch as the application's user
#
USER "${APP_USER}"
WORKDIR "${HOME_DIR}"

EXPOSE 8161
EXPOSE 61613
EXPOSE 61616

VOLUME [ "${DATA_DIR}" ]
VOLUME [ "${CONF_DIR}" ]
VOLUME [ "${LOGS_DIR}" ]
VOLUME [ "${TEMP_DIR}" ]

ENTRYPOINT [ "/entrypoint" ]
