#!/bin/bash
# functions.bash — test helpers for shell script tests
# 共通ライブラリの関数をテスト用にエクスポート

# このファイルは tests/ ディレクトリにある場合を想定
_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_ROOT="$(cd "${_TESTS_DIR}/.." && pwd)"
_LIB_DIR="${_PROJECT_ROOT}/.devcontainer/scripts/lib"

# 色定義（テスト環境でも使用）
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 共通ライブラリのsource
# shellcheck source=/dev/null
source "${_LIB_DIR}/logging.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/retry.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/version.sh"
# shellcheck source=/dev/null
source "${_LIB_DIR}/workspace.sh"

# ollama_architecture() — lib にない共通関数
ollama_architecture() {
    case "$(uname -m)" in
        x86_64) printf '%s\n' 'amd64' ;;
        aarch64|arm64) printf '%s\n' 'arm64' ;;
        *)
            echo "Unsupported Ollama architecture: $(uname -m)" >&2
            return 1
            ;;
    esac
}

# apt_installed_version() — lib にない共通関数
apt_installed_version() {
    dpkg-query -W -f='${Version}\n' "$1" 2>/dev/null || true
}

# npm_package_latest_version() — lib にない共通関数
npm_package_latest_version() {
    npm view "$1" version 2>/dev/null | head -1
}

# print_already_current() — テスト環境用
print_already_current() {
    echo -e "${GREEN}  Already up to date (${1})${NC}"
}

# update_tool() — update-tools.sh のスタブ（テスト用）
update_tool() {
    local tool="$1"
    case "$tool" in
        unknown-tool-xyz)
            echo -e "${RED}Unknown tool: ${tool}${NC}" >&2
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

unset _TESTS_DIR
unset _PROJECT_ROOT
unset _LIB_DIR
