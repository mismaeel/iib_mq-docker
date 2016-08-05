# Dockerfile for installing iib alongside MQ

FROM ubuntu:14.04

MAINTAINER Peter Weismann Peter.Weismann@yandex.com

# Update repository, install curl, bash, bc, rpm, tar packages
RUN apt-get update && \
    apt-get install -y curl bash bc rpm tar && \
    rm -rf /var/lib/apt/lists/*
	
# MQ: Copy all needed scripts to image and make them executable
COPY mq.sh /usr/local/bin/
COPY mq-license-check.sh /usr/local/bin/
COPY *.mqsc /etc/mqm/
RUN chmod a+rx /usr/local/bin/*.sh 

# Install MQ Developer Edition
RUN export DEBIAN_FRONTEND=noninteractive \
  # The URL to download the MQ installer from in tar.gz format
  && MQ_URL=http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqadv/mqadv_dev90_linux_x86-64.tar.gz \
  # The MQ packages to install
  && MQ_PACKAGES="MQSeriesRuntime-*.rpm MQSeriesServer-*.rpm MQSeriesMsg*.rpm MQSeriesJava*.rpm MQSeriesJRE*.rpm MQSeriesGSKit*.rpm" \
  # Optional: Update the command prompt
  && echo "mq:9.0" > /etc/debian_chroot \
  # Download and extract the MQ installation files
  && mkdir -p /tmp/mq \
  && cd /tmp/mq \
  && curl -LO $MQ_URL \
  && tar -zxvf ./*.tar.gz \
  # Recommended: Create the mqm user ID with a fixed UID and group, so that the file permissions work between different images
  && groupadd mqm \
  && useradd --gid mqm --home-dir /var/mqm mqm \
  && usermod -G mqm root \
  && cd /tmp/mq/MQServer \
  # Accept the MQ license
  && ./mqlicense.sh -text_only -accept \
  # Install MQ using the RPM packages
  && rpm -ivh --force-debian $MQ_PACKAGES \
  # Recommended: Set the default MQ installation (makes the MQ commands available on the PATH)
  && /opt/mqm/bin/setmqinst -p /opt/mqm -i \
  # Clean up all the downloaded files
  && rm -rf /tmp/mq \
  && rm -rf /var/lib/apt/lists/*
  
# IIB: Copy all needed scripts to image and make them executable
COPY kernel_settings.sh /tmp/
COPY iib_manage.sh /usr/local/bin/
COPY iib-license-check.sh /usr/local/bin/
COPY iib_env.sh /usr/local/bin/
RUN chmod +x /tmp/kernel_settings.sh
RUN chmod +x /usr/local/bin/*.sh

# Install IIB V10 Developer edition
RUN mkdir /opt/ibm && \
    curl http://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/integration/iib-10.0.0.0.tar.gz \
    | tar zx --directory /opt/ibm --exclude='tools' && \
    /opt/ibm/iib-10.0.0.0/iib make registry global accept license silently

# Configure system
RUN echo "IIB_10:" > /etc/debian_chroot  && \
    touch /var/log/syslog && \
    chown syslog:adm /var/log/syslog && \
    /tmp/kernel_settings.sh

# Create user to run as
RUN useradd --create-home --home-dir /home/iibuser -G mqbrkrs,sudo iibuser && \
    sed -e 's/^%sudo	.*/%sudo	ALL=NOPASSWD:ALL/g' -i /etc/sudoers 

RUN echo "#!/bin/bash" > /home/iibuser/.bash_profile && \
	sed -e "$ a . /opt/ibm/iib-10.0.0.0/server/bin/mqsiprofile " -i /home/iibuser/.bash_profile

RUN cat /etc/sudoers > /tmp/sudoers 

# Set BASH_ENV to source mqsiprofile when using docker exec bash -c
ENV BASH_ENV=/usr/local/bin/iib_env.sh

# Expose default admin port and http port
EXPOSE 1414 4414 7800 9080

#USER iibuser

# Always put the MQ data directory in a Docker volume
VOLUME /var/mqm

# Run mq setup script
CMD ["/bin/sh", "-c", "mq.sh"]
# Set entrypoint to run management script
ENTRYPOINT ["iib_manage.sh"]
