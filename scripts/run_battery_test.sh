#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROFILE="${1:-${PROFILE:-balanced}}"
INTERVAL="${INTERVAL:-30}"

case "$PROFILE" in
  quick)
    CPU_THREADS="${CPU_THREADS:-2}"
    MEM_MB="${MEM_MB:-512}"
    ENABLE_VIDEO="${ENABLE_VIDEO:-0}"
    ENABLE_GPU="${ENABLE_GPU:-0}"
    ;;
  balanced|cpu-mem)
    CPU_THREADS="${CPU_THREADS:-4}"
    MEM_MB="${MEM_MB:-1024}"
    ENABLE_VIDEO="${ENABLE_VIDEO:-0}"
    ENABLE_GPU="${ENABLE_GPU:-0}"
    ;;
  video)
    CPU_THREADS="${CPU_THREADS:-4}"
    MEM_MB="${MEM_MB:-1024}"
    ENABLE_VIDEO="${ENABLE_VIDEO:-1}"
    ENABLE_GPU="${ENABLE_GPU:-0}"
    ;;
  full)
    CPU_THREADS="${CPU_THREADS:-4}"
    MEM_MB="${MEM_MB:-2048}"
    ENABLE_VIDEO="${ENABLE_VIDEO:-1}"
    ENABLE_GPU="${ENABLE_GPU:-1}"
    ;;
  *)
    echo "Perfil desconhecido: $PROFILE" >&2
    echo "Use: quick | balanced | video | full" >&2
    exit 2
    ;;
esac

LOG_ROOT="${LOG_ROOT:-$ROOT_DIR/logs}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$PROFILE"
RUN_DIR="$LOG_ROOT/$RUN_ID"
RUNNING_FILE="$RUN_DIR/RUNNING"

VIDEO_SIZE="${VIDEO_SIZE:-1920x1080}"
VIDEO_RATE="${VIDEO_RATE:-30}"
VIDEO_SECONDS_PER_CHUNK="${VIDEO_SECONDS_PER_CHUNK:-300}"
FFMPEG_PRESET="${FFMPEG_PRESET:-veryfast}"

pids=()
cleanup_started=0

cleanup() {
  local exit_code="${1:-$?}"
  trap - EXIT INT TERM

  if [[ "$cleanup_started" == "1" ]]; then
    exit "$exit_code"
  fi
  cleanup_started=1

  rm -f "$RUNNING_FILE" || true

  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done

  sleep 1

  for pid in "${pids[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done

  for pid in "${pids[@]}"; do
    wait "$pid" 2>/dev/null || true
  done

  if [[ -f "$RUN_DIR/battery_test_log.csv" ]]; then
    python3 "$ROOT_DIR/scripts/summarize_log.py" "$RUN_DIR/battery_test_log.csv" > "$RUN_DIR/summary.txt" 2>/dev/null || true
  fi

  exit "$exit_code"
}
trap cleanup EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

mkdir -p "$RUN_DIR"
ln -sfn "$RUN_DIR" "$LOG_ROOT/latest"
touch "$RUNNING_FILE"

cat > "$RUN_DIR/run_config.env" <<CFG
PROFILE=$PROFILE
INTERVAL=$INTERVAL
CPU_THREADS=$CPU_THREADS
MEM_MB=$MEM_MB
ENABLE_VIDEO=$ENABLE_VIDEO
ENABLE_GPU=$ENABLE_GPU
VIDEO_SIZE=$VIDEO_SIZE
VIDEO_RATE=$VIDEO_RATE
VIDEO_SECONDS_PER_CHUNK=$VIDEO_SECONDS_PER_CHUNK
FFMPEG_PRESET=$FFMPEG_PRESET
START_DATETIME=$(date --iso-8601=seconds)
CFG

make all

start_logger() {
  "$ROOT_DIR/build/battery_logger" \
    "$RUN_DIR/battery_test_log.csv" \
    "$INTERVAL" \
    "$CPU_THREADS" \
    "$MEM_MB" \
    > "$RUN_DIR/logger.stdout.log" \
    2> "$RUN_DIR/logger.stderr.log" &
  pids+=("$!")
}

start_ffmpeg_video() {
  if [[ "$ENABLE_VIDEO" != "1" ]]; then
    return 0
  fi

  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg não encontrado; vídeo desativado." | tee -a "$RUN_DIR/warnings.log"
    return 0
  fi

  (
    while [[ -f "$RUNNING_FILE" ]]; do
      ffmpeg -nostdin -hide_banner -loglevel warning \
        -f lavfi -i "testsrc2=size=${VIDEO_SIZE}:rate=${VIDEO_RATE}" \
        -f lavfi -i "sine=frequency=1000:sample_rate=48000" \
        -t "$VIDEO_SECONDS_PER_CHUNK" \
        -vf "format=yuv420p" \
        -c:v libx264 -preset "$FFMPEG_PRESET" \
        -c:a aac \
        -f null - >> "$RUN_DIR/ffmpeg.log" 2>&1 || sleep 2
    done
  ) &
  pids+=("$!")
}

start_gpu_workload() {
  if [[ "$ENABLE_GPU" != "1" ]]; then
    return 0
  fi

  local glmark_bin="${GLMARK_BIN:-}"
  if [[ -z "$glmark_bin" ]]; then
    for candidate in glmark2-es2-drm glmark2-es2-wayland glmark2; do
      if command -v "$candidate" >/dev/null 2>&1; then
        glmark_bin="$candidate"
        break
      fi
    done
  fi

  if [[ -z "$glmark_bin" ]]; then
    echo "glmark2 não encontrado; GPU workload desativado." | tee -a "$RUN_DIR/warnings.log"
    return 0
  fi

  (
    echo "Usando GPU workload: $glmark_bin ${GLMARK_ARGS:-}" >> "$RUN_DIR/glmark2.log"
    while [[ -f "$RUNNING_FILE" ]]; do
      "$glmark_bin" ${GLMARK_ARGS:-} >> "$RUN_DIR/glmark2.log" 2>&1 || sleep 5
    done
  ) &
  pids+=("$!")
}

start_logger
start_ffmpeg_video
start_gpu_workload

cat <<MSG | tee "$RUN_DIR/console.log"
Teste iniciado.
Perfil: $PROFILE
Diretório do log: $RUN_DIR
CSV principal: $RUN_DIR/battery_test_log.csv

Para acompanhar:
  tail -f "$RUN_DIR/battery_test_log.csv"

Para encerrar manualmente:
  Ctrl+C
MSG

while true; do
  if [[ ${#pids[@]} -gt 0 ]] && ! kill -0 "${pids[0]}" 2>/dev/null; then
    echo "Logger principal encerrou." | tee -a "$RUN_DIR/console.log"
    exit 1
  fi
  sleep 10
done
