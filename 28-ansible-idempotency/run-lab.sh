#!/usr/bin/env bash
# Run the naive playbook twice, then the idempotent one twice, and compare
# what the second run does in each case.
set -uo pipefail

cd "$(dirname "$0")"
OUT=./evidence
mkdir -p "$OUT"

# Ansible REFUSES to load an ansible.cfg from a world-writable directory — a
# config file anyone can edit is a remote-code-execution vector, since it can
# point at arbitrary plugin paths. It warns ("world-writable-dir") and then
# silently continues with defaults: no inventory, no hosts, "skipping: no hosts
# matched", and a playbook that appears to succeed while doing nothing.
#
# This repo lives on /mnt/d, a Windows drive mounted through DrvFs, where every
# file is 0777 and the permission cannot be fixed with chmod. Pointing
# ANSIBLE_CONFIG at the file explicitly is the documented override: an explicit
# path is trusted because the user named it.
export ANSIBLE_CONFIG="${PWD}/ansible.cfg"

run() { printf '\n$ %s\n' "$*"; "$@" 2>&1; }
hdr() { printf '\n========== %s ==========\n' "$*"; }

# Fresh containers so both playbooks start from an identical clean host.
reset_hosts() {
  for h in web01 web02; do
    docker rm -f "$h" >/dev/null 2>&1
    docker run -d --name "$h" debian:12 sleep infinity >/dev/null
    # Ansible needs python3 on the target; the debian image ships without it.
    docker exec "$h" sh -c 'apt-get update -qq && apt-get install -y -qq python3 >/dev/null 2>&1'
  done
}

# The signal this whole lab is about.
summary() {
  grep -E "^(web01|web02)\s+:" || true
}

echo "Preparing containers..."
reset_hosts

{
echo "======================================================================"
echo " ANSIBLE IDEMPOTENCY"
echo " date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

hdr "Syntax check and inventory"
run ansible-inventory --list --yaml
run ansible-playbook playbook.yml --syntax-check
run ansible all -m ping

# ================================================================== NAIVE
hdr "NAIVE PLAYBOOK — run 1 (clean hosts)"
ansible-playbook playbook-naive.yml 2>&1 | tail -25

hdr "NAIVE PLAYBOOK — run 2 (nothing should need doing)"
ansible-playbook playbook-naive.yml 2>&1 | tail -25

hdr "What two runs of the naive playbook actually did"
echo "
/etc/motd after two runs — the line was appended twice:"
run docker exec web01 cat /etc/motd
echo "
The user task failed on the second run (ignore_errors hid it):"
run docker exec web01 id appuser

# ============================================================== IDEMPOTENT
echo
echo "Resetting hosts to a clean state for a fair comparison..."
reset_hosts >/dev/null 2>&1

hdr "IDEMPOTENT PLAYBOOK — run 1 (clean hosts)"
ansible-playbook playbook.yml 2>&1 | tail -30

hdr "IDEMPOTENT PLAYBOOK — run 2 (this is the test)"
echo "
A correct playbook reports changed=0 here. Anything else is a task lying about
whether it did something."
ansible-playbook playbook.yml 2>&1 | tail -30

hdr "State after two runs"
echo "
/etc/motd — one line, not two:"
run docker exec web01 cat /etc/motd
run docker exec web01 cat /etc/app.conf
run docker exec web01 id appuser
run docker exec web01 ls -la /var/lib/app-seeded

# ================================================================ CHECK MODE
hdr "--check --diff — what WOULD change, without changing it"
echo "
Only possible because the modules are declarative: they can compare desired
state against reality without applying anything. The naive playbook's shell
tasks cannot do this at all — a shell command has no dry run."
run docker exec web01 sh -c "sed -i 's/log_level=info/log_level=debug/' /etc/app.conf"
run ansible-playbook playbook.yml --check --diff

echo "
The host was NOT modified by --check:"
run docker exec web01 grep log_level /etc/app.conf

hdr "Applying for real reverts the manual edit"
ansible-playbook playbook.yml --diff 2>&1 | tail -25
run docker exec web01 grep log_level /etc/app.conf
} | tee "$OUT/01-idempotency.txt"

echo
echo "Cleaning up containers..."
docker rm -f web01 web02 >/dev/null 2>&1
echo "Evidence written to ${OUT}/"
