#!/bin/sh
set -e

CLAUDE_DIR="${HOME}/.claude"

if [ -z "$(ls -A "${CLAUDE_DIR}" 2>/dev/null)" ]; then
  cat <<EOF
==========================================================
 Claude Code is not authenticated yet.

 1) exec into the pod:
      kubectl exec -it -n claude-remote deploy/claude-remote -- bash
 2) inside the pod, run:
      claude
    then type "/login" and complete the OAuth flow.
 3) exit, then restart the deployment:
      kubectl rollout restart -n claude-remote deploy/claude-remote
==========================================================
EOF
  exec sleep infinity
fi

exec "$@"
