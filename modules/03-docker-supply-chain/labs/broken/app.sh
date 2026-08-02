#!/bin/sh
# Minimal stand-in for pulse-worker: logs, then persists state.
set -e

echo "worker starting (pid $$)"
trap 'echo "worker received SIGTERM, draining"; exit 0' TERM

i=0
while [ $i -lt 5 ]; do
  echo "tick $i"
  i=$((i + 1))
  sleep 1
done

echo "persisting state to /data/state.json"
echo '{"ticks":5}' > /data/state.json
echo "state persisted"

# Stay alive so stop behaviour can be observed.
sleep 300 &
wait $!
