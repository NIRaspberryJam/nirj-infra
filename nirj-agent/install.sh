#!/usr/bin/env bash
set -Eeuo pipefail

readonly DEFAULT_REPO_URL="https://github.com/NIRaspberryJam/nirj-agent.git"
readonly INSTALL_DIR="/data/nirj"
readonly REPO_DIR="${INSTALL_DIR}/agent-repo"
readonly VENV_DIR="${INSTALL_DIR}/agent-venv"
readonly RUNNER="${INSTALL_DIR}/run.sh"
readonly SERVICE_FILE="/etc/systemd/system/nirj-agent.service"

REPO_URL="${NIRJ_AGENT_REPO_URL:-${DEFAULT_REPO_URL}}"
BRANCH="${NIRJ_AGENT_BRANCH:-main}"
ASSET_ID=""
DEVICE_TYPE=""

usage() {
    echo "Usage: $0 --asset-id ID --device-type pi5|lpt-lx"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --asset-id)
            ASSET_ID="${2:-}"
            shift 2
            ;;
        --device-type)
            DEVICE_TYPE="${2:-}"
            shift 2
            ;;
        --branch)
            BRANCH="${2:-}"
            shift 2
            ;;
        --repo-url)
            REPO_URL="${2:-}"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ "$(id -u)" -ne 0 ]]; then
    echo "This installer must run as root" >&2
    exit 1
fi

if ! mountpoint --quiet /data; then
    echo "/data must be a mounted persistent filesystem before installation" >&2
    exit 1
fi

if [[ -z "${ASSET_ID}" ]]; then
    echo "--asset-id is required" >&2
    exit 2
fi

case "${DEVICE_TYPE}" in
    pi5|lpt-lx) ;;
    *)
        echo "--device-type must be pi5 or lpt-lx" >&2
        exit 2
        ;;
esac

if [[ ! "${BRANCH}" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    echo "Invalid branch name: ${BRANCH}" >&2
    exit 2
fi

export DEBIAN_FRONTEND=noninteractive
export PIP_DISABLE_PIP_VERSION_CHECK=1

apt-get update
apt-get install --yes \
    ca-certificates \
    git \
    python3 \
    python3-pip \
    python3-venv

install -d -m 0755 "${INSTALL_DIR}"
install -d -m 0755 \
    "${INSTALL_DIR}/config" \
    "${INSTALL_DIR}/state" \
    "${INSTALL_DIR}/logs" \
    "${INSTALL_DIR}/cache"

if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "Using existing repository at ${REPO_DIR}"
    git -C "${REPO_DIR}" fetch origin "${BRANCH}"
    if git -C "${REPO_DIR}" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
        git -C "${REPO_DIR}" checkout "${BRANCH}"
    else
        git -C "${REPO_DIR}" checkout --track -b "${BRANCH}" "origin/${BRANCH}"
    fi
    git -C "${REPO_DIR}" merge --ff-only "origin/${BRANCH}"
elif [[ -e "${REPO_DIR}" ]]; then
    echo "${REPO_DIR} exists but is not a Git repository" >&2
    exit 1
else
    git clone \
        --branch "${BRANCH}" \
        --single-branch \
        "${REPO_URL}" \
        "${REPO_DIR}"
fi

python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip setuptools
"${VENV_DIR}/bin/python" -m pip install --upgrade "${REPO_DIR}"

install -m 0755 "${REPO_DIR}/scripts/run-agent.sh" "${RUNNER}"

if [[ ! -e "${INSTALL_DIR}/config/config.yaml" ]]; then
    "${VENV_DIR}/bin/nirj-agent" setup \
        --asset-id "${ASSET_ID}" \
        --device-type "${DEVICE_TYPE}"
else
    echo "Preserving existing ${INSTALL_DIR}/config/config.yaml"
fi

ln -sfn "${VENV_DIR}/bin/nirj-agent" /usr/local/bin/nirj-agent

cat >"${SERVICE_FILE}" <<EOF
[Unit]
Description=NIRJ device management agent
Wants=network-online.target
After=network-online.target
ConditionPathExists=${INSTALL_DIR}/config/config.yaml

[Service]
Type=simple
WorkingDirectory=${REPO_DIR}
Environment=PYTHONUNBUFFERED=1
Environment=NIRJ_AGENT_BRANCH=${BRANCH}
ExecStart=${RUNNER}
Restart=on-failure
RestartSec=30
TimeoutStopSec=90

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now nirj-agent.service

echo "nirj-agent installed and started"
systemctl --no-pager status nirj-agent.service
