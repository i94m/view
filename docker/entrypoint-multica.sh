#!/bin/bash

# Derive the git host from GIT_VIEW_CODE (fallback to the TKE git host).
GIT_HOST="$(printf '%s' "${GIT_VIEW_CODE:-}" | sed -nE 's#^https?://([^/]+)/.*#\1#p')"
GIT_HOST="${GIT_HOST:-git.ap.tkelevator.com}"

[ -n "${GIT_USERNAME:-}" ] && git config --global user.name "${GIT_USERNAME}" || true
[ -n "${GIT_EMAIL:-}" ] && git config --global user.email "${GIT_EMAIL}" || true

# NOTE: passwords/tokens containing @ : / % must be URL-encoded; prefer an access token.
if [ -n "${GIT_USERNAME:-}" ] && [ -n "${GIT_PASSWORD:-}" ]; then
  git config --global credential.helper store || true
  umask 077
  printf 'https://%s:%s@%s\n' "${GIT_USERNAME}" "${GIT_PASSWORD}" "${GIT_HOST}" \
    > "${HOME}/.git-credentials" || true
fi

git config --global --add safe.directory "/opt/tk" 2>/dev/null || true
git config --global --add safe.directory "/opt/ai_asset" 2>/dev/null || true
git config --global init.defaultBranch main 2>/dev/null || true

# ---------------------------------------------------------------------------
# multica daemon（本地 agent runtime）自启动
#   - 认证：daemon 只认 ${HOME}/.multica/config.json，需先自行 multica login 生成。
#   - 设 MULTICA_DAEMON_AUTOSTART=0 可关闭
#   - daemon 异常退出后 30s 自动重拉（容器内没有 systemd，Docker 的
#     restart 策略只管 PID 1，所以这里自己兜一层）
# ---------------------------------------------------------------------------
MULTICA_DAEMON_BOOT_LOG="${MULTICA_DAEMON_BOOT_LOG:-/var/log/multica-daemon-boot.log}"
if [ "${MULTICA_DAEMON_AUTOSTART:-1}" != "0" ] && command -v multica >/dev/null 2>&1; then
  if [ -f "${HOME}/.multica/config.json" ]; then
    (
      # 注意：如果 multica 的 cwd 位于工作目录根内，它会认为自己是
      # 「daemon 托管的任务」而拒绝执行 daemon start/status，
      # 所以先切到中性目录（工作目录根默认是 /root/multica_workspaces，cwd 是 /opt/tk）。
      cd / 2>/dev/null || cd "${HOME}" 2>/dev/null || true
      while true; do
        multica daemon start --foreground >>"${MULTICA_DAEMON_BOOT_LOG}" 2>&1 || true
        echo "[entrypoint] $(date -Is) multica daemon exited, retry in 30s" >>"${MULTICA_DAEMON_BOOT_LOG}"
        sleep 30
      done
    ) &
    echo "[entrypoint] multica daemon autostart enabled (log: ${MULTICA_DAEMON_BOOT_LOG})"
  else
    echo "[entrypoint] multica daemon autostart skipped: no ${HOME}/.multica/config.json"
  fi
fi

# Hand over to the base image entrypoint (apache / php-fpm / redis / memcached).
exec /run/entrypoint.sh
