#!/usr/bin/env bash
# 本地构建 multica-runtime 镜像（base → runtime）。
#
#   ./docker/build.sh                     # 按本机架构构建，加载到本地 docker（推荐）
#   ./docker/build.sh --no-cache          # 忽略缓存重建
#   ./docker/build.sh --platform linux/amd64,linux/arm64 --push
#                                         # 多架构并推送（慢；会覆盖 registry 上同名 tag 的 manifest）
#
# 默认只 --load 不 --push：单平台 push 会把 CI 推的双平台 manifest 覆盖掉，
# 导致另一种架构的同事拉不到镜像。

set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/i94m/view}"
PHP_VERSION="${PHP_VERSION:-8.4}"
BUILD_ROOT="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -m)" in
    arm64|aarch64) HOST_ARCH=arm64 ;;
    x86_64|amd64)  HOST_ARCH=amd64 ;;
    *) echo "不支持的宿主架构: $(uname -m)" >&2; exit 1 ;;
esac

PLATFORMS="linux/${HOST_ARCH}"
PUSH=0
CACHE_ARGS=()

# 可选：用 BASE_OS 指定基础系统镜像
BASE_OS_ARG=()
if [ -n "${BASE_OS:-}" ]; then
    BASE_OS_ARG=(--build-arg "BASE_OS=${BASE_OS}")
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --push)      PUSH=1 ;;
        --no-cache)  CACHE_ARGS+=(--no-cache) ;;
        --platform)  PLATFORMS="$2"; shift ;;
        -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
    shift
done

BASE_TAG="${IMAGE_NAME}:php${PHP_VERSION}"
RUNTIME_TAG="${IMAGE_NAME}:php${PHP_VERSION}-multica"

# 本地构建走 `docker build`（当前 context 的 docker driver builder）：只有它能在构建时
# 直接 FROM 本地已有的 base 镜像；docker-container builder 会去 registry 拉 php8.4 而失败。
# 推送时才用 buildx（需要 docker-container driver 才能多平台）。
if [ "${PUSH}" -eq 1 ]; then
    echo "!! --push 会覆盖 ${IMAGE_NAME}:php${PHP_VERSION} 的 manifest，慎用" >&2
    build() { docker buildx build --push "$@"; }
else
    build() { docker build "$@"; }
fi

echo ">> base    ${BASE_TAG}    (${PLATFORMS})"
build \
    --platform "${PLATFORMS}" \
    ${CACHE_ARGS[@]+"${CACHE_ARGS[@]}"} ${BASE_OS_ARG[@]+"${BASE_OS_ARG[@]}"} \
    -t "${BASE_TAG}" \
    "${BUILD_ROOT}/base"

echo ">> runtime ${RUNTIME_TAG} (${PLATFORMS})"
build \
    --platform "${PLATFORMS}" \
    ${CACHE_ARGS[@]+"${CACHE_ARGS[@]}"} \
    --build-arg "BASE_IMAGE=${BASE_TAG}" \
    -t "${RUNTIME_TAG}" \
    "${BUILD_ROOT}/runtime"

echo
echo "完成："
echo "  ${BASE_TAG}"
echo "  ${RUNTIME_TAG}"
echo
echo "本地跑起来：docker compose up -d   （compose 里 image 用的就是 ${RUNTIME_TAG}）"
