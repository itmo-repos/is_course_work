#!/usr/bin/env bash
set -euo pipefail
DEMO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$DEMO_DIR/common.sh"
if [ "${DEMO_SKIP_TUNNEL:-0}" != 1 ]; then . "$DEMO_DIR/connection/tunnel.sh"; fi
DEMO_SCENARIO=storage
. "$DEMO_DIR/storage-story.sh"
