FROM apache/hive:3.1.3

USER root

ARG TEZ_VERSION=0.10.0
ENV TEZ_VERSION=${TEZ_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    krb5-user \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    rm -rf /opt/tez /tmp/apache-tez-bin.tar.gz /tmp/apache-tez-bin; \
    curl -fsSL "https://archive.apache.org/dist/tez/${TEZ_VERSION}/apache-tez-${TEZ_VERSION}-bin.tar.gz" -o /tmp/apache-tez-bin.tar.gz; \
    mkdir -p /tmp/apache-tez-bin; \
    tar -xzf /tmp/apache-tez-bin.tar.gz -C /tmp/apache-tez-bin; \
    mv "/tmp/apache-tez-bin/apache-tez-${TEZ_VERSION}-bin" /opt/tez; \
    rm -f /opt/tez/lib/guava-*.jar; \
    rm -f /opt/tez/lib/listenablefuture-*.jar; \
    rm -f /opt/tez/lib/hadoop-shaded-guava-*.jar; \
    rm -f /opt/tez/lib/slf4j-reload4j-*.jar; \
    rm -f /opt/tez/lib/hadoop-*.jar; \
    rm -rf /tmp/apache-tez-bin /tmp/apache-tez-bin.tar.gz

USER hive
