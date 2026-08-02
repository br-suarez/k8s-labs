#!/usr/bin/env bash
# Part 1: build naive vs multi-stage, compare size, layers and cache behaviour.
# Part 2: debug two containers that fail to start, using only logs/inspect/run.
set -uo pipefail

cd "$(dirname "$0")"
OUT=./evidence
mkdir -p "$OUT"

run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
hdr() { printf '\n========== %s ==========\n' "$*"; }

# =====================================================================
# PART 1 — image size and layers
# =====================================================================
{
echo "======================================================================"
echo " PART 1 — naive vs multi-stage"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

hdr "Building both images"
run docker build -q -t checkout-api:naive      -f app/Dockerfile.naive      app
run docker build -q -t checkout-api:multistage -f app/Dockerfile.multistage app

hdr "Size"
run docker images checkout-api --format 'table {{.Tag}}\t{{.Size}}'

echo "
Sizes reported by 'docker images' are uncompressed on-disk size. What actually
crosses the network on a pull is the compressed layers, so compare both."
run docker image inspect checkout-api:naive      --format '{{.RepoTags}} layers={{len .RootFS.Layers}}'
run docker image inspect checkout-api:multistage --format '{{.RepoTags}} layers={{len .RootFS.Layers}}'

hdr "Where the bytes are — largest layers, naive"
run sh -c "docker history checkout-api:naive --no-trunc --format '{{.Size}}\t{{.CreatedBy}}' | sort -hr | head -5 | cut -c1-160"

hdr "Where the bytes are — largest layers, multi-stage"
run sh -c "docker history checkout-api:multistage --no-trunc --format '{{.Size}}\t{{.CreatedBy}}' | sort -hr | head -5 | cut -c1-160"

hdr "What is actually inside each image"
echo "
Naive ships gcc, python3, 69 node_modules entries including the esbuild
devDependency, and runs as root.

Note what does NOT change: npm is present in BOTH. It ships with every
node:* base image including -alpine, so multi-stage does not remove it.
Getting rid of the package manager entirely needs a distroless or scratch
base image, which is a separate decision from multi-stage."
run sh -c "docker run --rm --entrypoint sh checkout-api:naive -c 'which npm node python3 gcc 2>/dev/null; echo \"node_modules entries: \$(ls /app/node_modules 2>/dev/null | wc -l)\"; echo \"esbuild present: \$(test -d /app/node_modules/esbuild && echo yes || echo no)\"; echo \"runs as uid: \$(id -u)\"'"
run sh -c "docker run --rm --entrypoint sh checkout-api:multistage -c 'which npm node python3 gcc 2>/dev/null; echo \"node_modules entries: \$(ls /app/node_modules 2>/dev/null | wc -l)\"; echo \"esbuild present: \$(test -d /app/node_modules/esbuild && echo yes || echo no)\"; echo \"runs as uid: \$(id -u)\"'"

hdr "Layer cache behaviour on a source-only change"
echo "
Changing one line of src/server.js and rebuilding both.

The first attempt at this used 'touch', which proved nothing: Docker's COPY
cache keys on file CONTENT, not mtime, so both builds were fully CACHED. The
file has to actually change."
cp app/src/server.js /tmp/server.js.bak
printf '\n// cache-bust %s\n' "$(date +%s)" >> app/src/server.js

echo
echo "--- naive rebuild (COPY . . before npm install) ---"
NAIVE_START=$(date +%s)
docker build -t checkout-api:naive -f app/Dockerfile.naive app 2>&1 \
  | grep -E "\[[0-9]+/[0-9]+\] (RUN|COPY)|CACHED" | head -8
NAIVE_END=$(date +%s)
echo "elapsed: $((NAIVE_END - NAIVE_START))s"

echo
echo "--- multi-stage rebuild (COPY package*.json first) ---"
MS_START=$(date +%s)
docker build -t checkout-api:multistage -f app/Dockerfile.multistage app 2>&1 \
  | grep -E "\[[a-z ]*[0-9]+/[0-9]+\] (RUN|COPY)|CACHED" | head -10
MS_END=$(date +%s)
echo "elapsed: $((MS_END - MS_START))s"

cp /tmp/server.js.bak app/src/server.js
echo
echo "(src/server.js restored)"

hdr "Both images still work"
run sh -c "docker run --rm -d --name verify-naive -p 3101:3000 checkout-api:naive >/dev/null && sleep 3 && curl -s localhost:3101/ && echo && docker rm -f verify-naive >/dev/null"
run sh -c "docker run --rm -d --name verify-ms -p 3102:3000 checkout-api:multistage >/dev/null && sleep 3 && curl -s localhost:3102/ && echo && docker rm -f verify-ms >/dev/null"
} | tee "$OUT/01-size-comparison.txt"

# =====================================================================
# PART 2 — debugging containers that will not start
# =====================================================================
{
echo "======================================================================"
echo " PART 2 — debugging two containers that fail to start"
echo "======================================================================"

# ---------------------------------------------------------- BUG 1
hdr "BUG 1 — builds fine, exits immediately"
run docker build -q -t checkout-api:broken-path -f app/Dockerfile.broken-path app

echo "
The build succeeded. Now run it:"
run sh -c "docker run --name dbg-path checkout-api:broken-path; echo \"exit code: \$?\""

echo "
Step 1 — what did it say before dying? The container is gone, but its logs are not."
run docker logs dbg-path

echo "
Step 2 — how did it exit? ExitCode 1 is the process refusing to run,
not the OOM killer (137) and not a SIGTERM (143)."
run docker inspect dbg-path --format 'State.ExitCode={{.State.ExitCode}}  OOMKilled={{.State.OOMKilled}}  Error="{{.State.Error}}"'

echo "
Step 3 — what was it actually told to run?"
run docker inspect dbg-path --format 'Cmd={{.Config.Cmd}}  Entrypoint={{.Config.Entrypoint}}  WorkingDir={{.Config.WorkingDir}}  User={{.Config.User}}'

echo "
Step 4 — 'docker exec' is useless here: the container is not running."
run sh -c "docker exec dbg-path ls /app/dist; echo \"exit: \$?\""

echo "
The way in is a NEW container from the same image with the entrypoint replaced,
which never runs the broken command:"
run docker run --rm --entrypoint sh checkout-api:broken-path -c "ls -la /app/dist"

echo "
CMD says dist/index.js. The file on disk is dist/server.js."
docker rm -f dbg-path >/dev/null 2>&1

# ---------------------------------------------------------- BUG 2
hdr "BUG 2 — right file, right command, still exits 1"
run docker build -q -t checkout-api:broken-perms -f app/Dockerfile.broken-perms app

run sh -c "docker run --name dbg-perms checkout-api:broken-perms; echo \"exit code: \$?\""

echo "
Step 1 — logs. This one reaches its own error handler, so the message is the
application's rather than node's:"
run docker logs dbg-perms

echo "
Step 2 — the file it wants exists and the command is correct, so this is not
bug 1 again:"
run docker run --rm --entrypoint sh checkout-api:broken-perms -c "ls -la /app/dist/server.js"

echo "
Step 3 — who owns the directory, and who is the process?"
run docker run --rm --entrypoint sh checkout-api:broken-perms -c "id; echo '--- /app ---'; ls -la /app"

echo "
Root owns /app; the container runs as uid 1000. EACCES.
Proof: run the same image as root and it starts."
run sh -c "docker run --rm -d --user 0 --name dbg-perms-root checkout-api:broken-perms >/dev/null && sleep 3 && docker logs dbg-perms-root && docker rm -f dbg-perms-root >/dev/null"
docker rm -f dbg-perms >/dev/null 2>&1

# ---------------------------------------------------------- FIXED
hdr "The fixed image does both correctly"
run sh -c "docker run --rm -d --name dbg-fixed -p 3103:3000 checkout-api:multistage >/dev/null && sleep 3 && docker logs dbg-fixed && curl -s localhost:3103/ && echo && docker rm -f dbg-fixed >/dev/null"
} | tee "$OUT/02-debug-session.txt"

echo
echo "Evidence written to ${OUT}/"
