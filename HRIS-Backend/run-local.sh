#!/usr/bin/env bash
#
# HRIS local runner.
# Menggunakan Config Server mode "native" (config lokal di ConfigServerGit/src/main/resources/config)
# dan infrastruktur dari docker-compose.yml.
#
# Pemakaian:
#   ./run-local.sh build    # build semua modul (butuh JDK 17)
#   ./run-local.sh start    # nyalakan infra + config server + semua service + gateway
#   ./run-local.sh stop     # matikan service (container tetap jalan)
#   ./run-local.sh down     # stop semua + matikan container
#   ./run-local.sh status   # cek status port
#   ./run-local.sh logs [nama]  # ikuti log (default semua)
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

COMPOSE_FILE="$ROOT/../docker-compose.yml"

JAVA_HOME="${JAVA_HOME:-$HOME/.local/opt/jdk-17.0.20.1+1}"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

LOG_DIR="${LOG_DIR:-/tmp/hris-logs}"
PID_DIR="$LOG_DIR/pids"
mkdir -p "$PID_DIR"

# nama:jar
SERVICES=(
  "auth:AuthMicroService/build/libs/AuthMicroService-v.0.1.jar"
  "admin:AdminMicroService/build/libs/AdminMicroService-v.0.1.jar"
  "company:CompanyMicroService/build/libs/CompanyMicroService-v.0.1.jar"
  "companyadmin:CompanyAdminMicroService/build/libs/CompanyAdminMicroService-v.0.1.jar"
  "personal:PersonalMicroService/build/libs/PersonalMicroService-v.0.1.jar"
  "elastic:ElasticMicroService/build/libs/ElasticMicroService-v.0.1.jar"
  "mail:MailModelService/build/libs/MailModelService-v.0.1.jar"
  "request:RequestMicroService/build/libs/RequestMicroService-v.0.1.jar"
)

start_one() {
  local name="$1" jar="$2" heap="${3:-400m}"
  setsid "$JAVA_HOME/bin/java" "-Xmx$heap" -jar "$jar" \
    > "$LOG_DIR/$name.log" 2>&1 < /dev/null &
  echo $! > "$PID_DIR/$name.pid"
  echo "  - $name (pid $!)"
}

wait_port() {
  local port="$1" tries="${2:-120}"
  for _ in $(seq 1 "$tries"); do
    if curl -sf -o /dev/null "http://localhost:$port" 2>/dev/null || \
       (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

case "${1:-start}" in
  build)
    ./gradlew :ConfigServerGit:bootJar \
      :AuthMicroService:build :AdminMicroService:build :CompanyMicroService:build \
      :CompanyAdminMicroService:build :PersonalMicroService:build :RequestMicroService:build \
      :ElasticMicroService:build :MailModelService:build :ApiGatewayService:build \
      -x test --no-daemon
    ;;

  start)
    echo "[1/4] Infrastruktur (docker compose)"
    docker compose -f "$COMPOSE_FILE" up -d
    echo "[2/4] Config Server :8888"
    start_one config ConfigServerGit/build/libs/ConfigServerGit-v.0.1.jar 300m
    echo "      menunggu config server..."
    wait_port 8888 120 || { echo "Config Server gagal start. Lihat $LOG_DIR/config.log"; exit 1; }
    echo "[3/4] Microservices"
    for s in "${SERVICES[@]}"; do start_one "${s%%:*}" "${s#*:}"; done
    echo "[4/4] API Gateway :8080"
    start_one gateway ApiGatewayService/build/libs/ApiGatewayService-v.0.1.jar 300m
    echo
    echo "Selesai diluncurkan. Cek status: ./run-local.sh status"
    echo "Gateway: http://localhost:8080   Swagger: http://localhost:<port>/swagger-ui/index.html"
    ;;

  stop)
    echo "Menghentikan service..."
    for f in "$PID_DIR"/*.pid; do
      [ -e "$f" ] || continue
      pid="$(cat "$f")"
      kill "$pid" 2>/dev/null && echo "  - killed $(basename "$f" .pid) ($pid)"
      rm -f "$f"
    done
    ;;

  down)
    "$0" stop
    echo "Mematikan container..."
    docker compose -f "$COMPOSE_FILE" down
    ;;

  status)
    printf "%-14s %s\n" "SERVICE" "PORT"
    ss -ltn 2>/dev/null | grep -E ":(8888|8080|9090|9091|9092|9093|9094|9095|9096|9100)\b" \
      | awk '{print $4}' | sed 's/.*://' | sort -n | tr '\n' ' '
    echo
    docker compose -f "$COMPOSE_FILE" ps --format '{{.Name}}\t{{.Status}}' 2>/dev/null
    ;;

  logs)
    if [ -n "${2:-}" ]; then
      tail -f "$LOG_DIR/$2.log"
    else
      tail -f "$LOG_DIR"/*.log
    fi
    ;;

  *)
    echo "Pemakaian: $0 {build|start|stop|down|status|logs [nama]}"
    ;;
esac
