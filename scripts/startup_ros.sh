#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: startup_ros.sh <service_name> <container_name> [start|stop|enter|restart|status]"
  exit 1
fi

SERVICE_NAME="$1"
CONTAINER_NAME="$2"
ACTION="${3:-}"
COMPOSE_FILE="docker-compose.yml"

usage() {
  cat <<USAGE
Usage: $(basename "$0") <service_name> <container_name> [start|stop|enter|restart|status]

No action: interactive menu.
USAGE
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: docker command not found"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    echo "Error: docker compose is not available"
    exit 1
  fi

  if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: $COMPOSE_FILE not found in current directory"
    exit 1
  fi
}

xhost_plus() {
  if [ -z "${DISPLAY:-}" ]; then
    echo "Warning: DISPLAY is empty, skip xhost+"
    return 0
  fi

  if ! command -v xhost >/dev/null 2>&1; then
    echo "Warning: xhost not found, skip xhost+"
    return 0
  fi

  xhost +local:docker >/dev/null 2>&1 || true
}

container_running() {
  docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q '^true$'
}

do_start() {
  xhost_plus
  docker compose up -d "$SERVICE_NAME"
  echo "Started: $CONTAINER_NAME"
}

do_stop() {
  docker compose stop "$SERVICE_NAME"
  echo "Stopped: $CONTAINER_NAME"
}

do_enter() {
  xhost_plus
  if ! container_running; then
    docker compose up -d "$SERVICE_NAME"
  fi
  docker compose exec "$SERVICE_NAME" /bin/zsh
}

do_restart() {
  docker compose restart "$SERVICE_NAME"
  echo "Restarted: $CONTAINER_NAME"
}

do_status() {
  if container_running; then
    echo "Status: running"
  else
    echo "Status: stopped"
  fi
}

dispatch_action() {
  case "$1" in
    start|s) do_start ;;
    stop|c) do_stop ;;
    enter|exec|e) do_enter ;;
    restart|r) do_restart ;;
    status|t) do_status ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Invalid action: $1"
      usage
      exit 1
      ;;
  esac
}

interactive_menu() {
  echo "请输入指令控制 ${CONTAINER_NAME}: 启动(s) 重启(r) 进入(e) 关闭(c) 状态(t)"
  read -r choose
  dispatch_action "$choose"
}

main() {
  ensure_docker

  if [ -z "$ACTION" ]; then
    interactive_menu
  else
    dispatch_action "$ACTION"
  fi
}

main
