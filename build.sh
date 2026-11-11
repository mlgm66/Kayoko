#!/bin/bash
#
# Kayoko 打包脚本。
#
# 由 Theos 编译和打包，各方案的安装名称和路径不同，需分别编译。
#
# 用法：
#   ./build.sh roothide
#   ./build.sh rootless
#   ./build.sh rootful
#
# 可选环境变量：
#   THEOS=/path/to/theos       # 未设置或路径无效时自动查找
#
# DEB 输出到 ./packages/，文件名中的架构后缀用于区分不同方案。

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# 补充常用包管理器路径，确保精简 Shell 环境也能找到所需工具。
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

# --- 查找 Theos -------------------------------------------------------------
if [[ -z "${THEOS:-}" || ! -d "${THEOS:-}" ]]; then
    for candidate in "${HOME}/theos" /opt/theos "${HOME}/theos-roothide"; do
        if [[ -d "$candidate" ]]; then
            THEOS="$candidate"
            break
        fi
    done
fi
if [[ -z "${THEOS:-}" || ! -d "$THEOS" ]]; then
    echo "error: no Theos install found; set THEOS to your Theos path" >&2
    exit 1
fi
export THEOS

MAKE_BIN="$(command -v gmake || command -v make)"
PACKAGE_ID="$(awk -F': ' '/^Package:/{print $2; exit}' "$ROOT/control")"

cleanup_build_artifacts() {
    echo ""
    echo "==> Cleaning build cache…"
    "$MAKE_BIN" clean >/dev/null 2>&1 || true

    while IFS= read -r -d '' cache_dir; do
        rm -rf "$cache_dir"
    done < <(find "$ROOT" -type d -name .theos -prune -print0)

    find "$ROOT" -type f \( \
        -name '.DS_Store' -o \
        -name '*.o' -o \
        -name '*.Td' -o \
        -name '*.stamp' -o \
        -name '*.xcuserstate' \
    \) -delete 2>/dev/null || true
}

# --- 构建指定方案 ------------------------------------------------------------
# Theos 输出 <包名>_<版本>_<架构>.deb；方案决定安装布局，CPU 架构由根目录 Makefile 定义。
# theos_scheme 传给 THEOS_PACKAGE_SCHEME，rootful 使用空字符串。
build_one() {
    local label="$1"
    local theos_scheme="$2"

    echo ""
    echo "==> Building ${label} package (THEOS=${THEOS})…"

    THEOS_PACKAGE_SCHEME="$theos_scheme" "$MAKE_BIN" clean >/dev/null 2>&1 || true
    THEOS_PACKAGE_SCHEME="$theos_scheme" "$MAKE_BIN" package FINALPACKAGE=1
}

# --- 选择构建方案 ------------------------------------------------------------
scheme="${1:-}"
case "$scheme" in
    -h|--help|help)
        echo "Usage: ./build.sh [roothide|rootless|rootful]"
        exit 0
        ;;
    roothide|rootless|rootful) ;;
    *)
        echo "error: unknown scheme '$scheme'" >&2
        echo "Usage: ./build.sh [roothide|rootless|rootful]" >&2
        exit 1
        ;;
esac

trap cleanup_build_artifacts EXIT

case "$scheme" in
    roothide) build_one roothide roothide ;;
    rootless) build_one rootless rootless ;;
    rootful)  build_one rootful  ""       ;;
esac

echo ""
echo "==> Done. Packages in ./packages/:"
ls -1 "$ROOT/packages/${PACKAGE_ID}_"*.deb 2>/dev/null || true
