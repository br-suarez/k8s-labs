# Tracing toolbox.
#
# Built as a container rather than installed on the host: strace, perf and gdb
# all need root to install, and this keeps the lab reproducible on any machine
# with Docker instead of requiring sudo on the host.
#
# strace needs CAP_SYS_PTRACE, which Docker drops by default — see run-lab.sh
# for the required --cap-add and --security-opt flags.
FROM debian:12

RUN apt-get update -qq \
    && apt-get install -y -qq --no-install-recommends \
        strace \
        linux-perf \
        procps \
        python3 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY *.py /work/
RUN chmod +x /work/*.py

CMD ["sleep", "infinity"]
