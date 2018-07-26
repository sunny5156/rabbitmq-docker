FROM alpine:3.7

MAINTAINER sunny5156 <sunny5156@qq.com> 

#RUN echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.7/main" > /etc/apk/repositories

ARG TZ="Asia/Shanghai"

ENV TZ ${TZ}

ENV WORKER /worker
ENV SRC_DIR ${WORKER}/src

RUN apk upgrade --update \
    && apk add curl bash tzdata openssh xz \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && sed -i s/#PermitRootLogin.*/PermitRootLogin\ yes/ /etc/ssh/sshd_config \
    && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa \
    && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa \
    && ssh-keygen -q -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N '' \
    && ssh-keygen -t dsa -f /etc/ssh/ssh_host_ed25519_key -N '' \
    && echo "root:root" | chpasswd \
    && rm -rf /var/cache/apk/*
    
RUN apk add --no-cache git make musl-dev go mongodb 

RUN apk add python supervisor

RUN mkdir -p  /data/db ${WORKER}/data/supervisor/log  ${WORKER}/data/supervisor/run  ${WORKER}/src ${WORKER}/data/etcd/log/  ${WORKER}/data/cronsun/log/ /usr/lib/rabbitmq/plugins/

ADD config ${WORKER}/

#ADD lib/lrzsz-0.12.20.tar.gz ${SRC_DIR}/

# -----------------------------------------------------------------------------
# Install lrzsz
# ----------------------------------------------------------------------------- 
ENV lrzsz_version 0.12.20
RUN cd ${SRC_DIR} \
    && wget -q -O lrzsz-${lrzsz_version}.tar.gz  http://down1.chinaunix.net/distfiles/lrzsz-${lrzsz_version}.tar.gz \
    && tar -zxvf lrzsz-${lrzsz_version}.tar.gz  \
    && cd lrzsz-${lrzsz_version} \
    && ./configure \
    && make \
    && make install \
    && ln -s /usr/local/bin/lrz /usr/bin/rz \
	&& ln -s /usr/local/bin/lsz /usr/bin/sz
    

ADD shell/.bash_profile /root/
ADD shell/.bashrc /root/
#ADD run.sh /

RUN echo -e "#!/bin/bash\n/usr/sbin/sshd -D \nnohup supervisord -c /worker/supervisor/supervisord.conf" >>/etc/start.sh

#####################################################
ENV RABBITMQ_VERSION=3.6.15
ENV PLUGIN_BASE=v3.6.x
ENV DELAYED_MESSAGE_VERSION=0.0.1
ENV SHARDING_VERSION=3.6.x-fe42a9b6
ENV TOP_VERSION=3.6.x-2d253d39

RUN cd ${SRC_DIR} \
  && apk --update add coreutils erlang erlang-asn1 erlang-crypto erlang-eldap erlang-erts erlang-inets erlang-mnesia erlang-os-mon erlang-public-key erlang-sasl erlang-ssl erlang-xmerl \
  && wget -q -O ${SRC_DIR}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz https://www.rabbitmq.com/releases/rabbitmq-server/v${RABBITMQ_VERSION}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz \
  && mkdir -p /usr/lib/rabbitmq/lib /usr/lib/rabbitmq/etc  \
  && cd /usr/lib/rabbitmq/lib \
  #&& tar xvfz /tmp/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz \
  && xz -d ${SRC_DIR}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz \
  #&& rm ${SRC_DIR}/rabbitmq-server-generic-unix-${RABBITMQ_VERSION}.tar.xz  \
  && ln -s /usr/lib/rabbitmq/lib/rabbitmq_server-${RABBITMQ_VERSION}/sbin /usr/lib/rabbitmq/bin  \
  && ln -s /usr/lib/rabbitmq/lib/rabbitmq_server-${RABBITMQ_VERSION}/plugins /usr/lib/rabbitmq/plugins  \
  && wget -q -O  /usr/lib/rabbitmq/plugins/rabbitmq_delayed_message_exchange-${DELAYED_MESSAGE_VERSION}.ez  http://www.rabbitmq.com/community-plugins/${PLUGIN_BASE}/rabbitmq_delayed_message_exchange-${DELAYED_MESSAGE_VERSION}.ez  \
  && wget -q -O  /usr/lib/rabbitmq/plugins/rabbitmq_top-${TOP_VERSION}.ez http://www.rabbitmq.com/community-plugins/${PLUGIN_BASE}/rabbitmq_top-${TOP_VERSION}.ez

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
#RUN adduser -s /bin/bash -D -h /var/lib/rabbitmq rabbitmq

ADD config/erlang.cookie /var/lib/rabbitmq/.erlang.cookie
ADD config/rabbitmq.config /usr/lib/rabbitmq/etc/rabbitmq/

# Environment variables required to run
ENV ERL_EPMD_PORT=4369
ENV HOME /var/lib/rabbitmq
ENV PATH /usr/lib/rabbitmq/bin:$PATH

ENV RABBITMQ_LOGS=-
ENV RABBITMQ_SASL_LOGS=-
ENV RABBITMQ_DIST_PORT=25672
ENV RABBITMQ_SERVER_ERL_ARGS="+K true +A128 +P 1048576 -kernel inet_default_connect_options [{nodelay,true}]"
ENV RABBITMQ_CONFIG_FILE=/usr/lib/rabbitmq/etc/rabbitmq/rabbitmq
ENV RABBITMQ_ENABLED_PLUGINS_FILE=/usr/lib/rabbitmq/etc/rabbitmq/enabled_plugins
ENV RABBITMQ_MNESIA_DIR=/var/lib/rabbitmq/mnesia
ENV RABBITMQ_PID_FILE=/var/lib/rabbitmq/rabbitmq.pid

# Fetch the external plugins and setup RabbitMQ
RUN \
  apk --purge del curl tar gzip \
  && ln -sf /var/lib/rabbitmq/.erlang.cookie /root/ \
  #&& chown rabbitmq /var/lib/rabbitmq/.erlang.cookie \
  && chmod 0600 /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie  \
  && ls -al /usr/lib/rabbitmq/plugins/ 
  #&& rabbitmq-plugins list \
  #&& rabbitmq-plugins enable --offline \
  #      rabbitmq_delayed_message_exchange \
  #      rabbitmq_management \
  #      rabbitmq_management_visualiser \
  #      rabbitmq_consistent_hash_exchange \
  #      rabbitmq_federation \
  #      rabbitmq_federation_management \
  #      rabbitmq_mqtt \
  #      rabbitmq_shovel \
  #      rabbitmq_shovel_management \
  #      rabbitmq_stomp \
  #      rabbitmq_top \
  #      rabbitmq_web_stomp 
  #&& chown -R rabbitmq /usr/lib/rabbitmq /var/lib/rabbitmq

EXPOSE 4369 5671 5672 15672 25672

#USER rabbitmq
CMD /usr/lib/rabbitmq/bin/rabbitmq-server
