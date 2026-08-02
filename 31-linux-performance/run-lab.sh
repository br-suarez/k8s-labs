#!/usr/bin/env bash
# Three performance problems, three different diagnostic paths.
#
#   A. slow      -> strace -c finds a syscall storm
#   B. hung      -> strace -p finds the blocking syscall, /proc/fd names the file
#   C. CPU-bound -> strace finds NOTHING, which is the finding
set -uo pipefail

cd "$(dirname "$0")"
OUT=./evidence
mkdir -p "$OUT"
IMG=perf-toolbox:v1
CT=perf-lab

# strace needs CAP_SYS_PTRACE (Docker drops it) and an unconfined seccomp
# profile (the default one blocks ptrace outright).
DOCKER_RUN=(docker run -d --name "$CT" --cap-add=SYS_PTRACE --security-opt seccomp=unconfined "$IMG")

hdr() { printf '\n========== %s ==========\n' "$*"; }
run() { printf '\n$ %s\n' "${*//docker exec $CT /}"; docker exec "$CT" "$@" 2>&1; }
sh_in() { printf '\n$ %s\n' "$1"; docker exec "$CT" sh -c "$1" 2>&1; }

echo "Building toolbox image..."
docker rm -f "$CT" >/dev/null 2>&1
docker build -q -t "$IMG" workloads >/dev/null
"${DOCKER_RUN[@]}" >/dev/null

{
echo "======================================================================"
echo " LINUX PERFORMANCE DEBUGGING — strace and perf"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

# ==================================================================== A
hdr "CASE A — a report job that takes far too long"
echo "
Symptom: writing 200,000 rows takes seconds. The code is a plain loop over
f.write(). Nothing in the Python looks expensive."
sh_in "python3 /work/report_writer.py --mode=slow --rows=200000 --out=/tmp/slow.csv"

echo "
Step 1 — count syscalls. 'strace -c' summarises instead of printing every call,
which is the only usable form on a process making millions of them."
sh_in "strace -c -f python3 /work/report_writer.py --mode=slow --rows=200000 --out=/tmp/slow.csv 2>&1 | sed -n '/% time/,\$p' | head -9"

echo "
200,000 write() calls for 200,000 rows — one syscall per line. Each one is a
user->kernel transition. The fix is not faster code, it is fewer crossings:
remove the per-line flush and let the runtime buffer."
sh_in "strace -c -f python3 /work/report_writer.py --mode=fast --rows=200000 --out=/tmp/fast.csv 2>&1 | sed -n '/% time/,\$p' | head -9"

echo "
Identical output, different syscall count:"
sh_in "ls -l /tmp/slow.csv /tmp/fast.csv; cmp /tmp/slow.csv /tmp/fast.csv && echo 'files are byte-identical'"

echo "
Wall clock, three runs each:"
sh_in "for m in slow fast; do for i in 1 2 3; do python3 /work/report_writer.py --mode=\$m --rows=200000 --out=/tmp/\$m.csv; done; done"

# ==================================================================== B
hdr "CASE B — a service that starts and then hangs"
echo "
Symptom: it logs 'ready' and stops. No CPU, no error, no exit."
# The PID is captured with \$! and written to a file.
#
# The first version of this script used `pgrep -f stuck_service.py`, which
# returned TWO pids: the python process AND the `sh -c` wrapper, whose own
# command line contains the pattern being searched for. strace was then handed
# "62\n73" and failed with "Can't stat '73'". `pgrep -f` matching the shell that
# invoked it is a classic self-match, and it silently produced a wrong answer.
sh_in "nohup python3 /work/stuck_service.py > /tmp/stuck.log 2>&1 & echo \$! > /tmp/stuck.pid; sleep 3; cat /tmp/stuck.log; echo \"pid: \$(cat /tmp/stuck.pid)\""

echo "
Step 1 — is it running, and is it using CPU?"
sh_in "ps -o pid,stat,%cpu,%mem,etime,cmd -p \$(cat /tmp/stuck.pid)"

echo "
State S with 0% CPU: sleeping in a syscall. Not spinning, not crashed.
Step 2 — which syscall? /proc/PID/syscall answers without attaching:
the first field is the syscall NUMBER, the rest are its arguments."
sh_in "PID=\$(cat /tmp/stuck.pid); echo \"syscall: \$(cat /proc/\$PID/syscall)\"; echo \"wchan:   \$(cat /proc/\$PID/wchan)\"; echo; echo 'syscall 257 on x86-64 = openat'; grep -m1 ' 257 ' /usr/include/asm/unistd_64.h 2>/dev/null || true"

echo "
Step 3 — strace confirms it, and shows the call as unfinished because the
process is parked inside it rather than passing through it:"
sh_in "PID=\$(cat /tmp/stuck.pid); timeout 5 strace -p \$PID 2>&1 | head -6"

echo "
Step 4 — which FILE is it opening? /proc/PID/fd lists what it already holds:"
sh_in "PID=\$(cat /tmp/stuck.pid); ls -l /proc/\$PID/fd/; echo '--- cwd ---'; ls -l /proc/\$PID/cwd"

echo "
Opening a FIFO for reading blocks until a writer appears, and nothing ever
writes to this one. Proof — supply a writer and the process moves on:"
sh_in "PID=\$(cat /tmp/stuck.pid); echo 'order-1' > /tmp/orders.fifo; sleep 2; cat /tmp/stuck.log; kill \$PID 2>/dev/null; true"

# ==================================================================== C
hdr "CASE C — a slow service that strace cannot explain"
echo "
Symptom: pricing 140 orders takes seconds."
sh_in "python3 /work/pricing_engine.py --orders 140"

echo "
Step 1 — the same first move as case A: count syscalls."
sh_in "strace -c -f python3 /work/pricing_engine.py --orders 140 2>&1 | tail -14"

echo "
A few hundred syscalls, almost all interpreter startup. THIS IS THE FINDING:
the process is not waiting on the kernel at all, so it is not I/O, not the
network, and not a lock. It is burning CPU in user space, and strace is the
wrong tool from here on."
sh_in "perf stat -e task-clock,context-switches,page-faults python3 /work/pricing_engine.py --orders 140 2>&1 | tail -14"

echo "
Step 2 — sample where the CPU time actually goes."
sh_in "cd /tmp && perf record -q -F 499 -g -o /tmp/perf.data python3 /work/pricing_engine.py --orders 140 >/dev/null 2>&1; perf report -i /tmp/perf.data --stdio --sort symbol 2>/dev/null | head -18"

echo "
perf points at the CPython interpreter loop, which is correct and useless:
every Python function looks like _PyEval_EvalFrameDefault to a native profiler.
To go deeper the profiler has to understand Python frames."
sh_in "python3 -c \"
import cProfile, pstats, io, sys
sys.path.insert(0, '/work')
import pricing_engine as pe
pr = cProfile.Profile(); pr.enable()
for oid in range(140): pe.price_order(oid)
pr.disable()
s = io.StringIO(); pstats.Stats(pr, stream=s).sort_stats('cumulative').print_stats(6)
print(s.getvalue())
\""
} | tee "$OUT/01-diagnosis.txt"

docker rm -f "$CT" >/dev/null 2>&1
echo
echo "Evidence written to ${OUT}/"
