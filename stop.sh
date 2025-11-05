#!/bin/bash
set -Eeuo pipefail

# Gracefully stop ValueCell frontend/backend dev services
# - Stops common dev ports: 8000 (backend), 1420/5173 (frontend)
# - Options:
#   --frontend-only  Stop frontend ports only
#   --backend-only   Stop backend ports only
#   --no-agents      Skip stopping agent/background processes
#   -h, --help       Show usage

info()  { echo "[INFO]  $*"; }
success(){ echo "[ OK ]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERR ]  $*" 1>&2; }

stop_by_port() {
  local port="$1"
  local pids
  pids=$(lsof -ti tcp:"$port" || true)
  if [[ -z "$pids" ]]; then
    info "No process found on port $port"
    return 0
  fi

  info "Stopping processes on port $port: $pids"
  # Send SIGTERM first
  kill $pids 2>/dev/null || true
  sleep 1

  # Force kill remaining
  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then
      warn "PID $pid still alive, sending SIGKILL"
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  success "Port $port stopped"
}

stop_by_pattern() {
  local pattern="$1"
  local pids
  pids=$(pgrep -f "$pattern" || true)
  if [[ -z "$pids" ]]; then
    info "No process matching pattern: $pattern"
    return 0
  fi

  info "Stopping processes matching '$pattern': $pids"
  kill $pids 2>/dev/null || true
  sleep 1
  for pid in $pids; do
    if kill -0 "$pid" 2>/dev/null; then
      warn "PID $pid still alive, sending SIGKILL"
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  success "Pattern '$pattern' stopped"
}

print_usage() {
  cat <<'EOF'
Usage: ./stop.sh [options]

Description:
  Gracefully stops ValueCell dev services by terminating processes bound to common ports.

Options:
  --frontend-only   Stop frontend ports only (1420, 5173)
  --backend-only    Stop backend port only (8000)
  -h, --help        Show this help message
EOF
}

main() {
  local stop_frontend_flag=1
  local stop_backend_flag=1
  local stop_agents_flag=1

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --frontend-only) stop_backend_flag=0; shift ;;
      --backend-only)  stop_frontend_flag=0; shift ;;
      --no-agents)     stop_agents_flag=0; shift ;;
      -h|--help)       print_usage; exit 0 ;;
      *) error "Unknown argument: $1"; print_usage; exit 1 ;;
    esac
  done

  # Frontend ports (Vite/Tauri dev): 1420, 5173
  if (( stop_frontend_flag )); then
    info "Stopping frontend dev servers..."
    stop_by_port 1420
    stop_by_port 5173
  fi

  # Backend port (Uvicorn): 8000
  if (( stop_backend_flag )); then
    info "Stopping backend server..."
    stop_by_port 8000
  fi

  # Agent/background processes launched via uv run (modules under valuecell.agents)
  if (( stop_agents_flag )); then
    info "Stopping agent/background processes..."
    # Specific agents
    stop_by_pattern "valuecell.agents.auto_trading_agent"
    stop_by_pattern "valuecell.agents.news_agent"
    # Generic patterns (launch orchestrator and uv-run agents)
    stop_by_pattern "scripts/launch.py"
    stop_by_pattern "uv run .*valuecell.agents"
    stop_by_pattern "python3 -m valuecell.agents"
  fi

  success "All requested services stopped"
}

main "$@"