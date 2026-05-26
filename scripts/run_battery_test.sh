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
# Presets mais lentos (`slow`, `slower`) aumentam o consumo de energia.
FFMPEG_PRESET="${FFMPEG_PRESET:-medium}"
GLMARK_BIN_EFFECTIVE=""

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

  if [[ -s "$RUN_DIR/warnings.log" ]]; then
    {
      echo
      echo "Avisos"
      echo "======"
      cat "$RUN_DIR/warnings.log"
    } >> "$RUN_DIR/summary.txt" 2>/dev/null || true
  fi

  exit "$exit_code"
}
trap cleanup EXIT
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

log_warning() {
  echo "$1" | tee -a "$RUN_DIR/warnings.log"
}

compiler_available() {
  local configured_cc="${CC:-}"
  local compiler_cmd

  if [[ -n "$configured_cc" ]]; then
    compiler_cmd="${configured_cc%% *}"
    command -v "$compiler_cmd" >/dev/null 2>&1
    return
  fi

  command -v gcc >/dev/null 2>&1 || command -v cc >/dev/null 2>&1
}

logger_needs_build() {
  [[ ! -x "$ROOT_DIR/build/battery_logger" ]] && return 0
  [[ "$ROOT_DIR/src/battery_logger.c" -nt "$ROOT_DIR/build/battery_logger" ]] && return 0
  [[ "$ROOT_DIR/Makefile" -nt "$ROOT_DIR/build/battery_logger" ]] && return 0
  return 1
}

resolve_glmark_bin() {
  local candidate

  if [[ -n "${GLMARK_BIN:-}" ]]; then
    if command -v "$GLMARK_BIN" >/dev/null 2>&1; then
      GLMARK_BIN_EFFECTIVE="$GLMARK_BIN"
      return 0
    fi
    log_warning "GLMARK_BIN='$GLMARK_BIN' não foi encontrado; GPU workload desativado."
    return 1
  fi

  for candidate in glmark2-es2-drm glmark2-es2-wayland glmark2; do
    if command -v "$candidate" >/dev/null 2>&1; then
      GLMARK_BIN_EFFECTIVE="$candidate"
      return 0
    fi
  done

  log_warning "Nenhuma variante glmark2 encontrada; perfil $PROFILE seguirá sem workload de GPU ativo."
  return 1
}

check_dependencies() {
  local missing=0
  local deps=("bash" "make" "python3")

  echo "Verificando dependências essenciais..."
  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "ERRO: Dependência não encontrada: $cmd" >&2
      missing=1
    fi
  done

  if logger_needs_build && ! compiler_available; then
    echo "ERRO: build/battery_logger precisa ser compilado, mas nenhum compilador gcc/cc foi encontrado." >&2
    missing=1
  fi

  if [[ "$ENABLE_VIDEO" == "1" ]]; then
    if ! command -v ffmpeg >/dev/null 2>&1; then
      echo "ERRO: ffmpeg é obrigatório para o perfil '$PROFILE'." >&2
      missing=1
    fi
  fi

  if [[ "$ENABLE_GPU" == "1" ]]; then
    if ! resolve_glmark_bin; then
      ENABLE_GPU=0
    fi
  fi

  if [[ "$missing" -eq 1 ]]; then
    echo "Instale as dependências com './scripts/install_deps.sh' e tente novamente." >&2
    exit 1
  fi
}

mkdir -p "$RUN_DIR"
ln -sfn "$RUN_DIR" "$LOG_ROOT/latest"
touch "$RUNNING_FILE"

check_dependencies

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
GLMARK_BIN=${GLMARK_BIN_EFFECTIVE:-}
START_DATETIME=$(date --iso-8601=seconds)
CFG

make all
if [[ ! -x "$ROOT_DIR/build/battery_logger" ]]; then
  echo "ERRO: build/battery_logger não foi gerado por make all." >&2
  exit 1
fi

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
  # libx264 com preset configurável: codificação H.264 em software que estressa
  #   a CPU com estimativa de movimento, DCT e codificação de entropia.
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
  local glmark_bin="$GLMARK_BIN_EFFECTIVE"

  if [[ -z "$glmark_bin" ]]; then
    log_warning "Nenhuma variante glmark2 resolvida; GPU workload desativado."
    return 0
  fi

  (
    local failures=0
    local warned_failure=0
    echo "Usando GPU workload: $glmark_bin ${GLMARK_ARGS:-}" >> "$RUN_DIR/glmark2.log"
    while [[ -f "$RUNNING_FILE" ]]; do
      if "$glmark_bin" ${GLMARK_ARGS:-} >> "$RUN_DIR/glmark2.log" 2>&1; then
        failures=0
      else
        failures=$((failures + 1))
        if [[ "$failures" -ge 2 && "$warned_failure" -eq 0 ]]; then
          log_warning "GPU workload '$glmark_bin' falhou repetidamente; veja logs/latest/glmark2.log."
          warned_failure=1
        fi
        sleep 5
      fi
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
