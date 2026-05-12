#!/bin/bash
set -euo pipefail

# ==============================================================================
# Entrypoint for GitHub Actions self-hosted runner container
# Registers the runner, starts it, and deregisters on exit
# ==============================================================================

RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_WORKDIR="${RUNNER_WORKDIR:-/home/runner/_work}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,aci,linux,custom}"
RUNNER_GROUP="${RUNNER_GROUP:-Default}"

# Validate required environment variables
if [ -z "${GITHUB_URL:-}" ]; then
    echo "ERROR: GITHUB_URL is required (e.g., https://github.com/org/repo)"
    exit 1
fi

if [ -z "${RUNNER_TOKEN:-}" ]; then
    echo "ERROR: RUNNER_TOKEN is required (registration token from GitHub API)"
    exit 1
fi

echo "=== Configuring GitHub Actions Runner ==="
echo "  Name:   ${RUNNER_NAME}"
echo "  Labels: ${RUNNER_LABELS}"
echo "  URL:    ${GITHUB_URL}"
echo "  Work:   ${RUNNER_WORKDIR}"

# Configure the runner
./config.sh \
    --url "${GITHUB_URL}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --work "${RUNNER_WORKDIR}" \
    --unattended \
    --replace

# Deregister on exit (graceful cleanup)
cleanup() {
    echo "=== Removing runner registration ==="
    ./config.sh remove --token "${RUNNER_TOKEN}" || true
}
trap cleanup EXIT SIGTERM SIGINT

echo "=== Starting runner ==="
./run.sh
