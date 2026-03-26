FROM apache/hive:3.1.3

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY --from=apache/impala:4.5.0-catalogd /opt/impala/lib /opt/impala-lib
COPY --chown=hive:hive --chmod=755 entrypoint.sh /entrypoint.sh

USER hive

ENTRYPOINT ["/entrypoint.sh"]
