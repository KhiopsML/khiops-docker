# Args available to every stages
# they need to be declared again (but not redefined) if used in any stage (after the FROM clause)
# ------------------------------------------
# Images tags
ARG SERVER_REVISION=0.1.6
ARG SERVER_IMAGE=ghcr.io/khiopsml/khiops-server:${SERVER_REVISION}
ARG BASE_TAG=24.04
# Khiops variables
ARG KHIOPS_CORE_PACKAGE_NAME=khiops-core-openmpi
ARG KHIOPS_VERSION=11.0.1

# Base image
# ------------------------------------------
FROM ubuntu:$BASE_TAG AS base
SHELL ["/bin/bash", "-c"]

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
COPY docker-entrypoint.sh cpu_count.sh /
RUN mkdir -p /scripts
COPY run_service.sh /scripts
RUN chmod +x /docker-entrypoint.sh cpu_count.sh /scripts/run_service.sh && \
 usermod -a -G root ubuntu

USER ubuntu
ENTRYPOINT ["/usr/bin/tini", "--", "/docker-entrypoint.sh"]

CMD []
VOLUME ["/khiops", "/scripts"]
HEALTHCHECK NONE

# Slim image (will use native system packages for Khiops)
# ------------------------------------------
FROM base AS slim
USER root

# Khiops variables
ARG KHIOPS_CORE_PACKAGE_NAME
ARG KHIOPS_VERSION
# Drivers versions
ARG GCS_DRIVER_VERSION=0.0.23
ARG S3_DRIVER_VERSION=0.0.25
ARG AZURE_DRIVER_VERSION=0.0.18

# hadolint ignore=SC2155,SC2086,DL3008
RUN source /etc/os-release && \
 CODENAME=$VERSION_CODENAME && \
 BUILDARCH=$(dpkg --print-architecture) && \
 apt-get update && \
 apt-get -y install --no-install-recommends ca-certificates wget openmpi-bin libopenmpi3t64 && \
 TEMP_DEB="$(mktemp)" && \
 wget "https://github.com/KhiopsML/khiops/releases/download/${KHIOPS_VERSION}/${KHIOPS_CORE_PACKAGE_NAME}_${KHIOPS_VERSION}-1-${CODENAME}.${BUILDARCH}.deb" -O "$TEMP_DEB" && \
 dpkg -i "$TEMP_DEB" || apt-get -f -y install --no-install-recommends && \
 rm -f $TEMP_DEB && \
 wget "https://github.com/KhiopsML/khiopsdriver-gcs/releases/download/${GCS_DRIVER_VERSION}/khiops-driver-gcs_${GCS_DRIVER_VERSION}-1-${CODENAME}.${BUILDARCH}.deb" -O "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" || apt-get -f -y install --no-install-recommends && \
 rm -f $TEMP_DEB && \
 wget "https://github.com/KhiopsML/khiopsdriver-s3/releases/download/${S3_DRIVER_VERSION}/khiops-driver-s3_${S3_DRIVER_VERSION}-1-${CODENAME}.${BUILDARCH}.deb" -O "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" || apt-get -f -y install --no-install-recommends && \
 rm -f $TEMP_DEB && \
 wget "https://github.com/KhiopsML/khiopsdriver-azure/releases/download/${AZURE_DRIVER_VERSION}/khiops-driver-azure_${AZURE_DRIVER_VERSION}-1-${CODENAME}.${BUILDARCH}.deb" -O "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" || apt-get -f -y install --no-install-recommends && \
 rm -f $TEMP_DEB && \
 rm -rf /var/lib/apt/lists/*
USER ubuntu

# Khiops slim + server (will mechanically use native system packages for Khiops)
# ------------------------------------------
# hadolint ignore=DL3006
FROM $SERVER_IMAGE AS server
FROM slim AS full
COPY --from=server /service /usr/bin/service

ENV SERVE_HTTP=false
ENV HTTP_PORT=11000
ENV GRPC_PLAINTEXT=false
ENV GRPC_PORT=10000

EXPOSE 10000 11000

ARG port=2222

USER root
# hadolint ignore=SC2155,SC2086,DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    openssh-client \
    libcap2-bin \
    dnsutils && \
    rm -rf /var/lib/apt/lists/*
# Add priviledge separation directory to run sshd as root.
RUN mkdir -p /var/run/sshd && \
    # Add capability to run sshd as non-root.
    setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/sshd && \
    apt-get remove libcap2-bin -y && apt-get autoremove -y

# Allow OpenSSH to talk to containers without asking for confirmation
# by disabling StrictHostKeyChecking.
# mpi-operator mounts the .ssh folder from a Secret. For that to work, we need
# to disable UserKnownHostsFile to avoid write permissions.
# Disabling StrictModes avoids directory and files read permission checks.
RUN sed -i "s/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g" /etc/ssh/ssh_config \
    && echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config \
    && sed -i "s/[ #]\(.*Port \).*/ \1$port/g" /etc/ssh/ssh_config \
    && sed -i "s/#\(StrictModes \).*/\1no/g" /etc/ssh/sshd_config \
    && sed -i "s/#\(Port \).*/\1$port/g" /etc/ssh/sshd_config && \
    echo "    SendEnv KHIOPS*" >> /etc/ssh/ssh_config && \
    echo "    SendEnv Khiops*" >> /etc/ssh/ssh_config && \
    echo "    SendEnv AWS_*" >> /etc/ssh/ssh_config && \
    echo "    SendEnv S3_*" >> /etc/ssh/ssh_config && \
    echo "    SendEnv GOOGLE_*" >> /etc/ssh/ssh_config && \
    echo "    SendEnv AZURE_*" >> /etc/ssh/ssh_config

RUN useradd -m  -g root mpiuser
WORKDIR /home/mpiuser
# Configurations for running sshd as non-root.
COPY --chown=mpiuser:0 sshd_config .sshd_config
RUN echo "Port $port" >> .sshd_config && \
    echo "AcceptEnv KHIOPS*" >> .sshd_config && \
    echo "AcceptEnv Khiops*" >> .sshd_config && \
    echo "AcceptEnv AWS_*" >> .sshd_config && \
    echo "AcceptEnv S3_*" >> .sshd_config && \
    echo "AcceptEnv GOOGLE_*" >> .sshd_config && \
    echo "AcceptEnv AZURE_*" >> /etc/ssh/ssh_config

WORKDIR /home/ubuntu
RUN cp /home/mpiuser/.sshd_config . && \
    chown ubuntu .sshd_config
USER ubuntu
RUN sed -i s/mpiuser/ubuntu/ .sshd_config


# Khiops desktop image
# ------------------------------------------
FROM slim AS desktop
USER root

# Packages versions
ARG KHIOPS_CORE_PACKAGE_NAME
ARG KHIOPS_VERSION
ARG KHIOPS_VISUALIZATION_VERSION=11.8.0
ARG KHIOPS_SAMPLES_VERSION=11.0.0

# The native system package for Khiops is used
# hadolint ignore=SC2155,SC2086,DL3008,DL4006
RUN source /etc/os-release && \
 CODENAME=$VERSION_CODENAME && \
 BUILDARCH=$(dpkg --print-architecture) && \
 export KHIOPS_VERSION=$(apt-cache policy ${KHIOPS_CORE_PACKAGE_NAME} | grep Install | cut -d ' ' -f 4 | awk -F '-' '{printf $1; i = 2; while (i < NF) { printf "-"$i; ++i } }') && \
 TEMP_DEB="$(mktemp)" && \
 wget "https://github.com/KhiopsML/khiops/releases/download/${KHIOPS_VERSION}/khiops_${KHIOPS_VERSION}-1-${CODENAME}.${BUILDARCH}.deb" -O "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 tag="v${KHIOPS_VISUALIZATION_VERSION//-/}" && \
 wget "https://github.com/KhiopsML/khiops-visualization-desktop/releases/download/${tag}/Khiops-Visualization-Desktop-${KHIOPS_VISUALIZATION_VERSION}_${BUILDARCH}.deb" -O "$TEMP_DEB" && \
 dpkg -i --force-all "$TEMP_DEB" && \
 rm -f $TEMP_DEB && \
 apt-get update && \
 apt -y --fix-broken install && \
 apt purge --auto-remove -y 'fonts-dejavu*' && \
 apt -f -y install --no-install-recommends locales unzip fonts-noto fonts-noto-cjk fonts-noto-color-emoji && \
 locale-gen en_US.UTF-8 && \
 rm -rf /var/lib/apt/lists/*

COPY xdg-open /usr/bin/xdg-open
RUN chmod 755 /usr/bin/xdg-open

USER ubuntu
WORKDIR /home/ubuntu
RUN TEMP_ZIP="$(mktemp --suffix=.zip)" && \
  wget "https://github.com/KhiopsML/khiops-samples/releases/download/${KHIOPS_SAMPLES_VERSION}/khiops-samples-${KHIOPS_SAMPLES_VERSION}.zip" -O "$TEMP_ZIP" && \
  unzip "$TEMP_ZIP" && \
  rm -f $TEMP_ZIP && \
  mkdir .config

# Fix for desktop application crash when paths contain UTF8 characters
ENV LANG=en_US.UTF-8

# Fix for MacOS broken display 
ENV JAVA_TOOL_OPTIONS='-Dsun.java2d.xrender=false'


# khiops-python image (will use system-wide packages of Khiops installed via Pip)
# ------------------------------------------
FROM full AS pykhiops
USER root

# Version of the Khiops Python library Pip package on the PyPI or Test PyPI repositories
# this version can be either official, following this pattern : [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+
# or pre-release (alpha, beta, release candidate), following this other pattern : [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(rc|a|b)[0-9]+
ARG KHIOPS_PYTHON_VERSION=11.0.1.0

# hadolint ignore=DL3008,DL4006
RUN apt-get --allow-unauthenticated update && \
 apt-get --allow-unauthenticated install --no-install-recommends -y \
 python3-pip \
 python3-all \
 python-is-python3 && \
 rm -rf /var/lib/apt/lists/*

# Remove the native system packages of Khiops core and remote files drivers to avoid any conflict
RUN apt-get remove -y "khiops-*"

# Install the whole Khiops stack (GUI-less) via Pip
# hadolint ignore=SC2102
RUN pip install --break-system-packages khiops[s3,gcs,azure]==${KHIOPS_PYTHON_VERSION}

# Install python KNI binding
# Make python3 the default python
RUN pip install --no-cache-dir --break-system-packages khiops-kni && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1

COPY fix-permissions.sh /usr/local/bin/
# hadolint ignore=DL3059
RUN chmod 755 /usr/local/bin/fix-permissions.sh && \
    NB_GID=1034 fix-permissions.sh /usr/local/bin /bin /lib 

USER ubuntu

