#!/usr/bin/env python3
"""A service that starts, logs that it is ready, and then does nothing.

No CPU, no error, no exit. `top` shows 0%, the process is in state S, and the
logs stop after "ready". This is the shape of an incident where the only
available information is "it is hung" — and where the answer is one strace away.
"""
import os
import sys
import time

FIFO = "/tmp/orders.fifo"

def main():
    print("starting order processor", flush=True)

    if not os.path.exists(FIFO):
        os.mkfifo(FIFO)

    print("connecting to upstream order feed", flush=True)
    print("ready", flush=True)

    # Opening a FIFO for reading blocks until a writer appears. Nothing ever
    # writes to this one, so the process waits here forever — with no error, no
    # timeout, and no log line.
    with open(FIFO, "r") as f:
        for line in f:
            print(f"processed: {line.strip()}", flush=True)

    print("upstream closed", flush=True)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
