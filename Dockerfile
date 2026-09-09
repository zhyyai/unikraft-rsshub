FROM diygod/rsshub:latest AS src

FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      binutils \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=src /app /app

COPY polyfill.cjs /usr/bin/polyfill.cjs
COPY wrapper.sh /usr/bin/wrapper.sh
COPY collect.sh /tmp/collect.sh
RUN chmod +x /usr/bin/wrapper.sh /tmp/collect.sh \
 && /tmp/collect.sh

FROM scratch
COPY --from=build /rootfs /

EXPOSE 1200
CMD ["/usr/bin/wrapper.sh"]
