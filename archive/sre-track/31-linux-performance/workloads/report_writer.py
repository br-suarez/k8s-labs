#!/usr/bin/env python3
"""Writes a report file. Slow, and the reason is not in the Python.

Two implementations that produce a byte-identical file:

  --mode=slow   flushes after every line
  --mode=fast   lets the runtime buffer

The point of the lab is that the source looks almost identical, the CPU profile
looks almost identical, and the wall-clock difference is enormous — because the
cost is in the syscall boundary, which is invisible from inside the process.
"""
import argparse
import os
import sys
import time

def write_report(path, rows, mode):
    with open(path, "w") as f:
        for i in range(rows):
            f.write(f"{i},order-{i},{i * 37 % 1000},shipped\n")
            if mode == "slow":
                # Looks harmless. It is one write(2) per line, plus the
                # user->kernel transition that comes with it.
                f.flush()
                os.fsync(f.fileno()) if False else None

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--mode", choices=["slow", "fast"], default="slow")
    p.add_argument("--rows", type=int, default=200000)
    p.add_argument("--out", default="/tmp/report.csv")
    a = p.parse_args()

    start = time.time()
    write_report(a.out, a.rows, a.mode)
    elapsed = time.time() - start

    size = os.path.getsize(a.out)
    print(f"mode={a.mode} rows={a.rows} bytes={size} elapsed={elapsed:.3f}s", file=sys.stderr)
