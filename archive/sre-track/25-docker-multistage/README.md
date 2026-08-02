# Refresher 25: Docker Multi-stage Builds & Container Debugging

**Module:** 25 — Hands-on refresher (SRE Track)
**Date:** 2026-08-02
**Format:** what broke → how it was diagnosed → the command that mattered

A small Node/Express service built two ways, then two containers that build
cleanly and die on start.

```bash
./run-lab.sh    # builds, compares, breaks, debugs — reproducible from scratch
```

Evidence: [`01-size-comparison.txt`](./evidence/01-size-comparison.txt),
[`02-debug-session.txt`](./evidence/02-debug-session.txt).

---

## Part 1 — naive vs multi-stage

| | naive | multi-stage |
|---|---|---|
| Size | **1.66 GB** | **235 MB** (−86%) |
| Layers | 12 | 7 |
| `gcc`, `python3` | present | absent |
| `node_modules` | 69 entries, incl. esbuild | 0 |
| Runs as | **root** (uid 0) | uid 1000 |
| Rebuild after a 1-line source edit | 6s, `npm install` re-runs | 2s, `npm ci` stays cached |

Where the naive image's bulk actually is:

```
619MB  apt-get install ... autoconf automake bzip2 default-libmysqlclient-dev dpkg-dev ...
213MB  node binary distribution
194MB  apt-get install ... git mercurial openssh-client subversion ...
133MB  debian bookworm rootfs
```

Roughly a gigabyte of build toolchain, in production, at runtime, forever.

### The layer-ordering half matters as much as the size

`Dockerfile.naive` does `COPY . .` **before** `npm install`. Any source change
invalidates that layer, so every dependency reinstalls:

```
--- naive rebuild (COPY . . before npm install) ---
#7 [3/5] COPY . .
#8 [4/5] RUN npm install      <- not cached
#9 [5/5] RUN npm run build
elapsed: 6s
```

`Dockerfile.multistage` copies `package*.json` on its own layer first.
Dependencies change far less often than source, so that layer survives:

```
--- multi-stage rebuild (COPY package*.json first) ---
#8  [build 3/6] COPY package*.json ./     CACHED
#10 [build 4/6] RUN npm ci                CACHED   <- the expensive step, skipped
#11 [build 5/6] COPY src ./src
#12 [build 6/6] RUN npm run build
elapsed: 2s
```

### What multi-stage does *not* fix

`npm` is still in the final image. It ships with every `node:*` base including
`-alpine`, and multi-stage does nothing about it — the 160 MB alpine node layer
is the single largest thing left. Removing the package manager entirely means a
`distroless` or `scratch` base, which is a separate decision.

I had assumed multi-stage got rid of it. It does not, and the evidence says so.

---

## Bug 1 — builds fine, exits immediately

**What broke.** The bundle is written to `dist/server.js`. `CMD` says
`dist/index.js`. Nothing validates that a `CMD` path exists, so `docker build`
succeeds completely.

**How it was diagnosed.**

```
$ docker logs dbg-path
Error: Cannot find module '/app/dist/index.js'
  code: 'MODULE_NOT_FOUND'
```

Then how it exited, which classifies the problem before reading anything else:

```
$ docker inspect dbg-path --format 'ExitCode={{.State.ExitCode}} OOMKilled={{.State.OOMKilled}}'
ExitCode=1  OOMKilled=false
```

Then what it was actually told to run — the image's own config, not the
Dockerfile you think you wrote:

```
$ docker inspect dbg-path --format 'Cmd={{.Config.Cmd}} WorkingDir={{.Config.WorkingDir}} User={{.Config.User}}'
Cmd=[node dist/index.js]  WorkingDir=/app  User=node
```

The instinct at this point is `docker exec`, and it does not work:

```
$ docker exec dbg-path ls /app/dist
Error response from daemon: container ... is not running
```

**The key command.** `exec` needs a running process. A container that died has
none. The way in is a *new* container from the same image with the entrypoint
replaced, so the broken command never runs:

```bash
docker run --rm --entrypoint sh checkout-api:broken-path -c "ls -la /app/dist"
```

```
-rw-r--r--  1 node node  1151023  server.js      <- CMD asked for index.js
```

---

## Bug 2 — right file, right command, still exits 1

**What broke.** `COPY --from=build` runs as root, then `USER node` takes over.
The app boots and tries to create its data directory under a root-owned `/app`.

**How it was diagnosed.** This one reaches the application's own error handler,
so the message is far better than a stack trace:

```
$ docker logs dbg-perms
FATAL: cannot write startup marker to /app/dist/data
EACCES: permission denied, mkdir '/app/dist/data'
```

`EACCES` immediately rules out bug 1 — the process started, ran its own code,
and failed on filesystem access. Confirm the file it needs is present, so this
is genuinely not a path problem:

```
$ docker run --rm --entrypoint sh checkout-api:broken-perms -c "ls -la /app/dist/server.js"
-rw-r--r--  1 root  root  1151023  /app/dist/server.js
```

`root root` on a file in an image that runs as `node` is the tell.

**The key command.** Compare the process identity against the directory owner in
the same breath:

```bash
docker run --rm --entrypoint sh checkout-api:broken-perms -c "id; ls -la /app"
```

```
uid=1000(node) gid=1000(node)
drwxr-xr-x  1 root  root   /app
drwxr-xr-x  2 root  root   dist
```

**The proof.** Change nothing but the user, and it starts:

```
$ docker run --rm --user 0 checkout-api:broken-perms
startup marker written to /app/dist/data
checkout-api listening on :3000
```

**The fix.** `RUN mkdir -p /app/dist/data && chown -R node:node /app` before
`USER node` — as in `Dockerfile.multistage`, which starts correctly as uid 1000:

```
{"service":"checkout-api","uid":1000,"node":"v22.23.2"}
```

---

## Issues encountered

**`npm ci` failed with no lockfile.** The first multi-stage build died on
`RUN npm ci` because the repo had `package.json` but no `package-lock.json`.
That is the whole difference between the two commands: `npm install` resolves
versions and writes a lockfile, `npm ci` refuses to run without one and installs
exactly what it says. The failure is the feature — a build that silently
resolved different dependency versions than the last one would be worse.
Generated with `npm install --package-lock-only` and committed.

**My cache demonstration proved nothing on the first run.** I used `touch` to
"change" the source, and both images rebuilt fully `CACHED` in 1s. Docker's
`COPY` cache keys on file **content**, not mtime. The test only became a test
once the file actually changed.

---

## What I re-learned

- **`docker exec` cannot debug the containers that most need debugging.** It
  attaches to a running process, and a container that fails at startup has none.
  `docker run --entrypoint sh <image>` is the actual tool: same filesystem, same
  user, same env, without executing the thing that breaks.

- **Read the image's config, not the Dockerfile.** `docker inspect
  --format '{{.Config.Cmd}}'` shows what the image really carries after every
  base-image `ENTRYPOINT`, override and build arg. Bug 1 was visible there in one
  line.

- **The exit code is a classifier, and checking it first is cheap.** `1` = the
  process refused to run, `137` = OOMKilled, `143` = SIGTERM. `docker inspect`
  reports `OOMKilled` as an explicit boolean, which is worth checking before
  concluding a container "just died".

- **Layer ordering is a build-time feature with a daily cost.** The size
  difference is what gets talked about; the 6s vs 2s rebuild is what an engineer
  pays for on every single commit. Both come from the same fix — put the things
  that rarely change in earlier layers.

- **Two assumptions I held were wrong, and the lab caught both.** Multi-stage
  does not remove `npm`, and `touch` does not invalidate a Docker layer. Neither
  would have surfaced from writing the Dockerfile carefully; both surfaced from
  running the comparison and reading the output.
