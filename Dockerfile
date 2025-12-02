FROM buildpack-deps:buster-curl as installer

ARG NACOS_VERSION=2.2.0.1
ARG HOT_FIX_FLAG=""

RUN set -x \
    && curl -SL --output /var/tmp/nacos-server.tar.gz https://github.com/alibaba/nacos/releases/download/${NACOS_VERSION}${HOT_FIX_FLAG}/nacos-server-${NACOS_VERSION}.tar.gz \
    && tar -xzvf /var/tmp/nacos-server.tar.gz -C /home \
    && rm -rf /var/tmp/nacos-server.tar.gz /home/nacos/bin/* /home/nacos/conf/*.properties /home/nacos/conf/*.example /home/nacos/conf/nacos-mysql.sql /home/nacos/target/nacos-server.jar

ADD bin/docker-startup.sh /home/nacos/bin/docker-startup.sh 
ADD conf/application.properties /home/nacos/conf/application.properties
ADD conf/nacos-gaussdb.sql /home/nacos/conf/nacos-gaussdb.sql
ADD nacos-server.jar /home/nacos/target/nacos-server.jar
ADD README.md /home/nacos/README.md

FROM liulik/openjdk:8-jre-slim

LABEL version="2.2.0.1" \
      maintainer="liulike" \
      description="使用华为GaussDB的JDBC 505.2.1构建的nacos-server" \
      application-name="nacos-server-gaussdb"

# set environment
ENV MODE="cluster" \
    PREFER_HOST_MODE="ip"\
    BASE_DIR="/home/nacos" \
    CLASSPATH=".:/home/nacos/conf:$CLASSPATH" \
    CLUSTER_CONF="/home/nacos/conf/cluster.conf" \
    FUNCTION_MODE="all" \
    NACOS_USER="nacos" \
    JAVA="/usr/local/openjdk-8/bin/java" \
    JVM_XMS="1g" \
    JVM_XMX="1g" \
    JVM_XMN="512m" \
    JVM_MS="128m" \
    JVM_MMS="320m" \
    NACOS_DEBUG="n" \
    TOMCAT_ACCESSLOG_ENABLED="false" \
    TZ="Asia/Shanghai"

WORKDIR $BASE_DIR

# copy nacos bin
COPY --from=installer ["/home/nacos", "/home/nacos"]

# set startup log dir
RUN mkdir -p logs \
    && cd logs \
    && touch start.out \
    && ln -sf /dev/stdout start.out \
    && ln -sf /dev/stderr start.out \
    && chmod +x /home/nacos/bin/docker-startup.sh

EXPOSE 8848
ENTRYPOINT ["bin/docker-startup.sh"]
