#!/usr/bin/env bash
set -euo pipefail

# Publish the Hookaido skill to ClawHub.
#
# The ClawHub CLI is pinned to a reviewed version instead of @latest so the
# publish path does not execute whatever was most recently published to npm.
# Bump CLAWHUB_VERSION deliberately after reviewing the new release.
#
# Prerequisites:
#   npx clawhub@0.23.3 login   (one-time, opens browser for GitHub OAuth)
#   npx clawhub@0.23.3 whoami  (verify auth)
#
# The --slug flag is required because the repository folder name
# (claw-skill-hookaido) differs from the skill slug on ClawHub (hookaido).
# The --name flag sets the display name shown in the ClawHub UI.
#
# Browse metadata is replaced on every publish, so keep it here rather than
# editing it on the website: at most 3 category slugs from the fixed ClawHub
# list, at most 5 free-form topics. Override the changelog with CHANGELOG="...".

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAWHUB_VERSION="0.23.3"

# Extract the skill version from SKILL.md frontmatter (metadata.version). It is
# kept out of the top level so SKILL.md also uploads to claude.ai and the
# Skills API, which reject unknown top-level keys.
VERSION="$(sed -n 's/^  version: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$SKILL_DIR/SKILL.md" | head -n 1)"

if [[ -z "$VERSION" ]]; then
  echo "Error: could not extract version from SKILL.md" >&2
  exit 1
fi

CATEGORIES="integrations,automation,operations"
TOPICS="Webhook,OpenClaw,GitHub,Message Queue,MCP"
DEFAULT_CHANGELOG="Hookaido ${VERSION}: OpenClaw Gateway integration (push to mapped hooks, pull relay for Gateways behind NAT), SHA256-verified installs, MCP works with Claude Code and OpenClaw, guidance corrected against the current release."
CHANGELOG="${CHANGELOG:-$DEFAULT_CHANGELOG}"

echo "Publishing hookaido@${VERSION} from ${SKILL_DIR}"

npx --yes "clawhub@${CLAWHUB_VERSION}" publish "$SKILL_DIR" \
  --slug hookaido \
  --name "Hookaido Webhook Integration" \
  --version "$VERSION" \
  --categories "$CATEGORIES" \
  --topics "$TOPICS" \
  --changelog "$CHANGELOG" \
  "$@"
