# Minimal Git server image.
#
# The obvious choice, `alpine/git`, does not work: Alpine ships the git daemon
# in a SEPARATE package from git itself, so `alpine/git` gives you
#   git: 'daemon' is not a git command.
# and the container crash-loops. Installing `git-daemon` explicitly is the fix.
FROM alpine:3.21

RUN apk add --no-cache git git-daemon

# Non-root: the daemon needs no privileges, and it writes only inside the
# mounted volume. 1000 matches the fsGroup set on the pod so the PVC is writable.
RUN adduser -D -u 1000 git
USER git

EXPOSE 9418
ENTRYPOINT ["git", "daemon", "--verbose", "--export-all", \
            "--enable=receive-pack", "--reuseaddr", \
            "--base-path=/srv/git", "/srv/git"]
