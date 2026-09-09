#!/bin/sh
set -e

export HOME=/tmp
export TMPDIR=/tmp
export NODE_ENV=production
export PORT=1200
export LISTEN_INADDR_ANY=1
export PATH="/usr/bin:/bin"

cd /app
echo "Starting RSSHub via Node.js on port 1200..."
exec /usr/bin/node /app/dist/index.mjs
