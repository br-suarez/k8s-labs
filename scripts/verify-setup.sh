#!/usr/bin/env bash
#
# Confirm the environment matches SETUP.md before module 01 starts.
# Thin wrapper: the real logic lives in the platform harness, which is the thing
# you will keep extending.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
exec ./platform/scripts/verify.sh tooling build scripts
