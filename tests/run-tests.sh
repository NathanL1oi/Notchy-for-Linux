#!/usr/bin/env bash
set -euo pipefail

ROOT="$(realpath "$(dirname "$0")/..")"

node --test "$ROOT"/tests/*.test.js

if command -v qmllint >/dev/null 2>&1; then
    qmllint \
        -I "$ROOT/plugin" \
        -I /usr/share/quickshell/dms \
        -I /usr/share/quickshell \
        "$ROOT"/plugin/*.qml
else
    printf '\nSKIP qmllint: 未安装，已完成 Node 逻辑与 QML 结构检查。\n'
fi
