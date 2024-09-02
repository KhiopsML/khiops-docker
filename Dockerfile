
ARG SERVER_REVISION=0.1.6
ARG SERVER_IMAGE=ghcr.io/khiopsml/khiops-server:${SERVER_REVISION}
ARG BASE_TAG=22.04

FROM ubuntu:$BASE_TAG AS base
ENV DEBIAN_FRONTEND=noninteractive
# hadolint ignore=DL3008
RUN apt-get update && \
 apt-get install --no-install-recommends -y \
    tini \
    libssl3 \
    lsb-release \
    && \
 rm -rf /var/lib/apt/lists/*

# install scripts
# ----------------

COPY docker-entrypoint.sh cpu_count.sh /
RUN mkdir -p /scripts
COPY run_service.sh /scripts
RUN chmod +x /docker-entrypoint.sh cpu_count.sh /scripts/run_service.sh && \
 useradd -rm -d /home/ubuntu -s /bin/bash -g root -u 1000 ubuntu

USER ubuntu
ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]

CMD []
VOLUME ["/khiops", "/scripts"]
HEALTHCHECK NONE

FROM base AS slim
USER root

# Define package versions
# ------------------------------------------
ARG KHIOPS_CORE_PACKAGE_NAME=khiops-core-openmpi
ARG KHIOPS_VERSION=10.2.2
ARG GCS_DRIVER_VERSION=0.0.10
ARG S3_DRIVER_VERSION=0.0.12

# install packages
# ----------------
# hadolint ignore=SC2155,SC2086,DL3008
RUN export CODENAME=$(lsb_release -cs) && \
 apt-get update && \
 apt-get -y install --no-install-recommends ca-certificates curl && \
 TEMP_DEB="$(mktemp)" && \
 curl -L "https://github.com/KhiopsML/khiops/releases/download/${KHIOPS_VERSION}/${KHIOPS_CORE_PACKAGE_NAME}_${KHIOPS_VERSION}-1-${CODENAME}.amd64.deb" -o "$TEMP_DEB" && \
 dpkg -i "$TEMP_DEB" || apt-get -f -y install --no-install-recommends && \
 rm -f $TEMP_DEB && \
 curl -L "https://github.com/sgouache/khiopsdriver-gcs/releases/download/${GCS_DRIVER_VERSION}/khiops-gcs_${GCS_DRIVER_VERSION}.deb" -o "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 rm -f $TEMP_DEB && \
 curl -L "https://github.com/sgouache/khiopsdriver-s3/releases/download/${S3_DRIVER_VERSION}/khiops-s3_${S3_DRIVER_VERSION}.deb" -o "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 rm -f $TEMP_DEB && \
 rm -rf /var/lib/apt/lists/*

USER ubuntu

# Khiops slim + server
# hadolint ignore=DL3006
FROM $SERVER_IMAGE AS server
FROM slim AS full
COPY --from=server /service /usr/bin/service

ENV SERVE_HTTP=false
ENV HTTP_PORT=11000
ENV GRPC_PLAINTEXT=false
ENV GRPC_PORT=10000

EXPOSE 10000 11000

# Khiops desktop version
FROM full AS desktop
USER root

# install packages
# ----------------
# hadolint ignore=SC2155,SC2086,DL3008,DL4006
RUN export CODENAME=$(lsb_release -cs) && \
 export KHIOPS_VERSION="$(apt-cache policy ${KHIOPS_CORE_PACKAGE_NAME} | grep Install | cut -d ' ' -f 4 | cut -d '-' -f 1)" && \
 TEMP_DEB="$(mktemp)" && \
 curl -L "https://github.com/KhiopsML/khiops/releases/download/${KHIOPS_VERSION}/khiops_${KHIOPS_VERSION}-1-${CODENAME}.amd64.deb" -o "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 apt-get update && \
 apt-get -f -y install --no-install-recommends && \
 rm -f $TEMP_DEB && \
 rm -rf /var/lib/apt/lists/*
USER ubuntu

# Intermediate image building python KNI binding
FROM desktop AS pykni
USER root

# install packages
# ----------------
# hadolint ignore=SC2155,SC2086,DL3008,DL4006
RUN export CODENAME=$(lsb_release -cs) && \
 export KHIOPS_VERSION="$(apt-cache policy ${KHIOPS_CORE_PACKAGE_NAME} | grep Install | cut -d ' ' -f 4 | cut -d '-' -f 1)" && \
 TEMP_DEB="$(mktemp)" && \
 curl -L "https://github.com/KhiopsML/khiops/releases/download/${KHIOPS_VERSION}/kni_${KHIOPS_VERSION}-1-${CODENAME}.amd64.deb" -o "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 rm -f $TEMP_DEB && \
 apt-get --allow-unauthenticated update && \
 apt-get --allow-unauthenticated install --no-install-recommends -y \
 swig3.0 \
 python3-pip \
 python3-all \
 python3-all-dev \
 build-essential && \
 rm -rf /var/lib/apt/lists/*

COPY kni/*.sh kni/KhiopsNativeInterface.i kni/README.md kni/setup.py /root/
WORKDIR /root
RUN chmod +x install.sh compile.sh && ./install.sh && ./compile.sh
USER ubuntu
# pykhiops version
FROM full AS pykhiops
USER root

ARG PYKHIOPS_VERSION=10.2.2.4

# install packages
# ----------------
# hadolint ignore=SC2155,SC2086,DL3008,DL4006
RUN export CODENAME=$(lsb_release -cs) && \
 export KHIOPS_VERSION="$(apt-cache policy ${KHIOPS_CORE_PACKAGE_NAME} | grep Install | cut -d ' ' -f 4 | cut -d '-' -f 1)" && \
 sed -i 's|path-exclude=/usr/share/doc/*|#path-exclude=/usr/share/doc/*|' /etc/dpkg/dpkg.cfg.d/excludes && \
 apt-get --allow-unauthenticated update && \
 TEMP_DEB="$(mktemp)" && \
 curl -L "https://github.com/KhiopsML/khiops/releases/download/${KHIOPS_VERSION}/kni_${KHIOPS_VERSION}-1-${CODENAME}.amd64.deb" -o "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 rm -f $TEMP_DEB && \
 apt-get --allow-unauthenticated install --no-install-recommends -y \
 python3-pip \
 python3-all \
 python-is-python3 && \
 rm -rf /var/lib/apt/lists/*

# hadolint ignore=SC2102
RUN pip install --no-cache-dir "https://github.com/KhiopsML/khiops-python/releases/download/${PYKHIOPS_VERSION}/khiops-${PYKHIOPS_VERSION}.tar.gz"

# Install python KNI binding
# Make python3 the default python
COPY --from=pykni /root/dist/KNI*.whl /tmp/
RUN pip install --no-cache-dir /tmp/KNI*.whl && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1

COPY fix-permissions.sh /usr/local/bin/
# hadolint ignore=DL3059
RUN chmod 755 /usr/local/bin/fix-permissions.sh && \
    NB_GID=1034 fix-permissions.sh /usr/local/bin /bin /lib 

USER ubuntu

