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
# O preset `medium` oferece um bom equilíbrio entre qualidade e uso de CPU.
# `veryfast` (padrão anterior) é muito leve e pode não estressar a CPU o suficiente.
# Presets mais lentos (`slow`, `slower`) aumentam o consumo de energia.
FFMPEG_PRESET="${FFMPEG_PRESET:-medium}"

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

check_dependencies() {
  local missing=0
  # Dependências essenciais para compilar, logar e sumarizar.
  # ffmpeg e glmark2 são verificados depois, pois são opcionais dependendo do perfil.
  local deps=("make" "gcc" "python3" "vcgencmd")

  echo "Verificando dependências essenciais..."
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERRO: Dependência não encontrada: $cmd" >&2
      missing=1
    fi
  done
  [[ "$missing" -eq 1 ]] && { echo "Instale as dependências com './scripts/install_deps.sh' e tente novamente." >&2; exit 1; }
}

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

check_dependencies
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

  # testsrc2: gerador de vídeo sintético colorido (sem leitura de disco).
  # libx264 -preset veryfast: codificação H.264 em software — estresa CPU de
  #   forma diferente de stress-ng (estimativa de movimento, DCT, entropia).
  # -f null -: descarta o vídeo gerado; o objetivo é carga de CPU, não armazenar.
  # O while loop reinicia o ffmpeg ao fim de cada chunk para manter a carga contínua.
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

  # O glmark2 tem três variantes no Raspberry Pi OS:
  #   glmark2-es2-drm   : usa KMS/DRM diretamente — funciona headless via SSH.
  #   glmark2-es2-wayland: requer servidor Wayland (desktop Raspberry Pi OS).
  #   glmark2           : variante genérica / fallback.
  # Priorizamos drm para que o perfil full funcione mesmo sem ambiente gráfico.
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
