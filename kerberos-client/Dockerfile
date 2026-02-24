FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    krb5-user \
    && rm -rf /var/lib/apt/lists/*

CMD ["sleep", "infinity"]
