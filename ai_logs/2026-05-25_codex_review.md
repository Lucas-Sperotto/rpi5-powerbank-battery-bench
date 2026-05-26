# Revisão Codex - 2026-05-25

## Resumo das alterações

- `src/battery_logger.c`: substituído parsing com `atoi`/`strtoull` sem validação por parsing com checagem de faixa, lixo textual e overflow de `mem_mb` em bytes.
- `src/battery_logger.c`: adicionada validação de escrita/sincronização do CSV, com retorno diferente de zero em falha de `dprintf`, `fsync`, `fstat` ou `close`.
- `src/battery_logger.c`: parsing de `vcgencmd get_throttled` agora valida se o número foi realmente lido e se sobrou apenas espaço em branco.
- `scripts/run_battery_test.sh`: script marcado como executável, `trap` instalado antes das etapas que podem falhar depois da criação do diretório, e `cleanup` tornado idempotente.
- `scripts/run_battery_test.sh`: limpeza agora remove `RUNNING`, envia `TERM`, depois `KILL` se necessário, aguarda os filhos com `wait` e gera `summary.txt` quando há CSV.
- `scripts/run_battery_test.sh`: `ffmpeg` agora usa `-nostdin`; `ffmpeg` e `glmark2` permanecem opcionais conforme o perfil.

## Comandos executados

```bash
date '+%F %T %Z %z'
make clean && make all
bash -n scripts/run_battery_test.sh
./build/battery_logger /tmp/codex_invalid_logger.csv abc 1 1
timeout --signal=INT --kill-after=5s 6s scripts/run_battery_test.sh quick
python3 scripts/summarize_log.py logs/latest/battery_test_log.csv
git diff --check
test ! -e logs/latest/RUNNING
pgrep -af '[b]uild/battery_logger|[r]un_battery_test.sh' || true
```

## Resultados

- Data local confirmada: `2026-05-25 23:46:10 -03 -0300`.
- `make clean && make all` passou sem warnings novos.
- `bash -n scripts/run_battery_test.sh` passou.
- Teste negativo do logger com `intervalo_s=abc` retornou `exit=2` e exibiu mensagem de uso/validação.
- `scripts/run_battery_test.sh quick` iniciou corretamente pelo caminho executável; o `timeout` retornou `124`, esperado para encerramento forçado pelo próprio `timeout`.
- O smoke test criou `logs/latest/battery_test_log.csv` e `logs/latest/summary.txt`.
- `scripts/summarize_log.py` interpretou o CSV gerado: 2 registros, duração de 6 segundos.
- `git diff --check` não encontrou problemas de whitespace.
- Após o encerramento, `RUNNING` foi removido e não restaram processos `battery_logger`/`run_battery_test.sh`.

## Pendências

- Este ambiente não aparenta ser um Raspberry Pi OS real: temperatura e frequência da CPU ficaram indisponíveis (`-1`) e `vcgencmd` retornou `NA`.
- Perfis `video` e `full` não foram exercitados neste smoke test; `ffmpeg` e `glmark2` continuam dependentes do ambiente e do hardware disponíveis.
- Recomenda-se repetir `scripts/run_battery_test.sh quick` no Raspberry Pi 5 antes do ensaio longo de bateria.
