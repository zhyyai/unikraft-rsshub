FROM diygod/rsshub:latest AS src

FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      binutils \
      file \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=src /app /app

# Drastic pre-pruning on /app to shrink from 139M to <70M
RUN rm -rf /app/node_modules/.cache \
           /app/.git \
           /app/docs \
           /app/coverage \
           /app/scripts \
           /app/pnpm-lock.yaml \
           /app/tsconfig*.json \
           /app/.env* \
 && find /app -type f \( \
      -name "*.map" -o \
      -name "*.d.ts" -o \
      -name "*.ts" -o \
      -name "*.tsx" -o \
      -name "*.md" -o \
      -name "*.markdown" -o \
      -name "*.txt" -o \
      -name "LICENSE*" -o \
      -name "LICENCE*" -o \
      -name "CHANGELOG*" -o \
      -name "README*" -o \
      -name "*.c" -o \
      -name "*.h" -o \
      -name "*.cpp" -o \
      -name "*.o" -o \
      -name "*.gyp" -o \
      -name "*.gypi" \
    \) -delete 2>/dev/null || true \
 && find /app -type d \( \
      -name "test" -o \
      -name "tests" -o \
      -name "__tests__" -o \
      -name "docs" -o \
      -name "example" -o \
      -name "examples" -o \
      -name ".github" -o \
      -name "man" -o \
      -name "benchmark" -o \
      -name "benchmarks" \
    \) -exec rm -rf {} + 2>/dev/null || true

COPY polyfill.cjs /usr/bin/polyfill.cjs
COPY wrapper.sh /usr/bin/wrapper.sh
COPY collect.sh /tmp/collect.sh
RUN chmod +x /usr/bin/wrapper.sh /tmp/collect.sh \
 && /tmp/collect.sh

FROM scratch
COPY --from=build /rootfs /

EXPOSE 1200
CMD ["/usr/bin/wrapper.sh"]
