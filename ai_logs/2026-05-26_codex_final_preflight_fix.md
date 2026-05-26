# Final preflight fix - Codex - 2026-05-26

## Objetivo

Deixar o repositório pronto para smoke tests no Raspberry Pi 5 antes do ensaio longo com power bank, alinhando documentação, comentários e pre-flight checks com a implementação real.

## Problema encontrado

- A documentação e comentários ainda citavam `stress-ng`, mas a carga real de CPU e memória é gerada pelo `battery_logger`.
- O script já usava `FFMPEG_PRESET=medium`, mas ainda havia comentários mencionando `veryfast`.
- O pre-flight check tratava `vcgencmd` como dependência essencial, embora o logger já suporte `NA` quando ele não está disponível.
- A documentação sobre GPU headless precisava refletir a prioridade real: `glmark2-es2-drm`, depois `glmark2-es2-wayland`, depois `glmark2`.

## Arquivos alterados

- `README.md`
- `docs/TEST_PLAN.md`
- `scripts/run_battery_test.sh`
- `TODO.md`
- `ai_logs/2026-05-26_codex_final_preflight_fix.md`

## Decisões tomadas

- CPU e memória foram documentadas como workloads internos do `battery_logger`.
- Vídeo foi documentado como `ffmpeg` com `testsrc2` e H.264 via `libx264` em software.
- O preset padrão de vídeo permanece `medium`.
- `ffmpeg` é obrigatório para perfis `video` e `full`; se estiver ausente, o script aborta antes de iniciar o teste.
- GPU é opcional no perfil `full`: se nenhuma variante do `glmark2` existir, o teste continua sem GPU ativa e registra aviso.
- `vcgencmd` não é dependência obrigatória; ausência dele aparece no CSV como `NA`.
- O pre-flight check usa `if` explícitos para ser compatível com `set -e`, evitando saída prematura quando uma dependência opcional não se aplica ao perfil.

## Comandos de validação executados

```bash
git status --short
grep -R "stress-ng" README.md docs/TEST_PLAN.md scripts/run_battery_test.sh || true
grep -R "veryfast" scripts/run_battery_test.sh README.md docs/TEST_PLAN.md || true
grep -R "preset" scripts/run_battery_test.sh README.md docs/TEST_PLAN.md || true
make clean && make all
bash -n scripts/run_battery_test.sh
timeout --signal=INT --kill-after=5s 20s ./scripts/run_battery_test.sh quick
python3 scripts/summarize_log.py logs/latest/battery_test_log.csv
git diff --check
git status --short
```

## Resultados obtidos

- `grep` por `stress-ng` em `README.md`, `docs/TEST_PLAN.md` e `scripts/run_battery_test.sh` não retornou resultados.
- `grep` por `veryfast` em `scripts/run_battery_test.sh`, `README.md` e `docs/TEST_PLAN.md` não retornou resultados.
- `grep` por `preset` retornou apenas as referências atuais ao preset configurável `medium` e ao argumento `-preset "$FFMPEG_PRESET"`.
- `make clean && make all` passou sem erro.
- `bash -n scripts/run_battery_test.sh` passou.
- `timeout --signal=INT --kill-after=5s 20s ./scripts/run_battery_test.sh quick` iniciou o perfil `quick`, criou CSV e `summary.txt`; o `timeout` retornou `124`, esperado para encerramento por tempo.
- `python3 scripts/summarize_log.py logs/latest/battery_test_log.csv` interpretou o CSV: 2 registros e duração de 20 segundos.
- `git diff --check` passou.
- Após o smoke test, `logs/latest/RUNNING` foi removido.
- Neste ambiente, `cpu_khz` ficou `-1` e `throttled` ficou `NA`, esperado fora de um Raspberry Pi OS com `vcgencmd` e sysfs de CPU disponíveis.

## Pendências para hardware real

- Repetir `quick` no Raspberry Pi 5 real.
- Validar os perfis `video` e `full` no Raspberry Pi 5 real.
- Confirmar qual variante de `glmark2` existe e executa corretamente no Raspberry Pi OS alvo.
- Criar `RESULTS.md` após o primeiro ensaio real.
- Fazer o teste longo na power bank somente depois que os smoke tests no Raspberry Pi 5 passarem.
