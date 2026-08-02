# Lab 03.03 — Three containers that build clean and fail at runtime

**CORE · 50 min**

## Context

A build that succeeds tells you the syntax was valid. These three all build
without a warning and all fail when you run them, in three different ways.

## Setup

```bash
cd modules/03-docker-supply-chain/labs/broken
docker build -t broken-1 -f Dockerfile.1 .
docker build -t broken-2 -f Dockerfile.2 .
docker build -t broken-3 -f Dockerfile.3 .
```

All three succeed. **Do not read the Dockerfiles yet.**

## The problem

For each image, in this order:

1. Run it and observe the symptom.
2. **Write your hypothesis before investigating.**
3. Diagnose it from the outside — you may not read the Dockerfile until you have
   a diagnosis.
4. Then read the Dockerfile and check whether you were right.
5. Fix it.

```bash
docker run --rm broken-1
docker run --rm broken-2
docker run --rm -d --name b3 broken-3 && sleep 5 && docker logs b3
```

Record for each: symptom, hypothesis, the command that confirmed it, and whether
your first hypothesis was correct.

## What to reach for

```bash
docker inspect <img> --format '{{json .Config}}' | jq
docker history <img> --no-trunc
docker create --name tmp <img> && docker export tmp | tar -tv | less
docker inspect <container> --format '{{.State.ExitCode}} {{.State.OOMKilled}} {{.State.Error}}'
docker events &          # then run the container
```

## Expected outcome

Three diagnoses, three fixes, and — most valuable — an honest record of which
first hypotheses were wrong.

## Staged hints

<details><summary>Hint — broken-1</summary>

It exits immediately with a non-zero code and a message about a file. The
message names a path. Is that path where you think it is? Check what
`WORKDIR` was when the binary was copied, and what it is when the binary runs.
</details>

<details><summary>Hint — broken-2</summary>

It starts and appears to run, but `docker stop` takes the full 10 seconds. It is
not hung. Look at `docker inspect --format '{{.Path}} {{.Args}}'` and think about
what is PID 1.
</details>

<details><summary>Hint — broken-3</summary>

It runs, logs normally, and then dies at a predictable point. `docker inspect`
the exit state before assuming it is an application bug. Then look at what the
image declares about resources versus what the process actually does.
</details>

## Why this lab exists

Every one of these three is a real production failure pattern, and none produces
a useful error message. The skill is generating hypotheses from thin symptoms and
knowing which command tests each one — which is the same skill the break-fix
grades.
