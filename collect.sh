#!/bin/bash
set -euo pipefail

ROOT=/rootfs
mkdir -p "$ROOT"

copy_file() {
  local src="$1"
  [ -e "$src" ] || return 0
  local real
  real=$(readlink -f "$src")
  mkdir -p "$ROOT$(dirname "$real")"
  if [ -d "$real" ] && [ ! -L "$real" ]; then
    mkdir -p "$ROOT$real"
    cp -a "$real"/. "$ROOT$real"/
  else
    [ -e "$ROOT$real" ] || cp -a "$real" "$ROOT$real"
  fi
  if [ "$src" != "$real" ]; then
    mkdir -p "$ROOT$(dirname "$src")"
    ln -sfn "$real" "$ROOT$src"
  fi
}

copy_tree() {
  local src="$1"
  [ -e "$src" ] || return 0
  if [ -d "$src" ] && [ ! -L "$src" ]; then
    mkdir -p "$ROOT$src"
    cp -a "$src"/. "$ROOT$src"/
  else
    copy_file "$src"
  fi
}

copy_bin_deps() {
  local bin="$1"
  [ -e "$bin" ] || return 0
  copy_file "$bin"
  if command -v ldd >/dev/null 2>&1 && ldd "$bin" >/dev/null 2>&1; then
    ldd "$bin" | awk '/=>/ {print $3} /^\// {print $1}' | while read -r lib; do
      [ -n "${lib:-}" ] && [ -e "$lib" ] && copy_file "$lib"
    done
  fi
}

copy_tree /app
copy_tree /etc/ssl
copy_tree /etc/ca-certificates
copy_tree /usr/share/ca-certificates
copy_tree /etc/os-release
copy_tree /usr/lib/os-release
copy_tree /etc/passwd
copy_tree /etc/group
copy_tree /etc/hosts
copy_tree /etc/nsswitch.conf
copy_tree /etc/ld.so.conf
copy_tree /etc/ld.so.conf.d

copy_file /usr/bin/polyfill.cjs

real_ld=$(readlink -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2)
mkdir -p "$ROOT/lib/x86_64-linux-gnu" "$ROOT/usr/lib/x86_64-linux-gnu" "$ROOT/lib64"
cp -a "$real_ld" "$ROOT/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
ln -sfn /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$ROOT/lib64/ld-linux-x86-64.so.2"
ln -sfn /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 "$ROOT/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"

for b in \
  /usr/bin/wrapper.sh \
  /usr/bin/node \
  /bin/sh /bin/dash
do
  copy_bin_deps "$b"
done

# Copy NSS DNS resolver and dynamic runtime libraries
find /lib/x86_64-linux-gnu /usr/lib/x86_64-linux-gnu -maxdepth 1 \( -name 'libnss*.so*' -o -name 'libresolv*.so*' \) 2>/dev/null | while read -r f; do
  copy_file "$f"
done

# Copy any native addons in /app if present
find /app -type f -name '*.node' 2>/dev/null | while read -r f; do
  copy_bin_deps "$f"
done

if [ -f /etc/resolv.conf ]; then
  copy_file /etc/resolv.conf
fi
if [ ! -s "$ROOT/etc/resolv.conf" ]; then
  cat > "$ROOT/etc/resolv.conf" << 'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
fi

mkdir -p "$ROOT/tmp" "$ROOT/run" "$ROOT/proc" "$ROOT/dev/shm" "$ROOT/root"
chmod 1777 "$ROOT/tmp" "$ROOT/dev/shm"

if command -v ldconfig >/dev/null 2>&1; then
  ldconfig -r "$ROOT" 2>/dev/null || true
fi

# --- Aggressive size pruning to satisfy KraftCloud 1.0 GiB storage quota ---
echo "Pruning non-runtime assets from /rootfs/app..."
find "$ROOT/app" -type f \( \
  -name "*.map" -o \
  -name "*.d.ts" -o \
  -name "*.md" -o \
  -name "*.markdown" -o \
  -name "*.txt" -o \
  -name "LICENSE*" -o \
  -name "CHANGELOG*" \
\) -delete 2>/dev/null || true

find "$ROOT/app" -type d \( \
  -name "test" -o \
  -name "tests" -o \
  -name "__tests__" -o \
  -name "docs" -o \
  -name "example" -o \
  -name "examples" \
\) -exec rm -rf {} + 2>/dev/null || true

# Strip node binary
if [ -f "$ROOT/usr/bin/node" ]; then
  strip --strip-unneeded "$ROOT/usr/bin/node" 2>/dev/null || true
fi

echo "=== Pruned rootfs size ==="
du -sh "$ROOT"
ls -l "$ROOT/lib64/ld-linux-x86-64.so.2"
