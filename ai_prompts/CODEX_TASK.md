# Prompt para Codex

Você está trabalhando no repositório `rpi5-powerbank-battery-bench`.

Objetivo: revisar e melhorar a implementação técnica do benchmark de bateria para Raspberry Pi 5 alimentado por power bank.

Tarefas:
1. Compile o projeto com `make clean && make all`.
2. Revise `src/battery_logger.c` quanto a segurança, tratamento de erro e portabilidade em Raspberry Pi OS.
3. Revise `scripts/run_battery_test.sh` quanto a encerramento limpo, criação de logs, uso de `ffmpeg` e `glmark2`.
4. Faça apenas alterações pequenas, objetivas e testáveis.
5. Crie ou atualize `ai_logs/YYYY-MM-DD_codex_review.md` com:
   - resumo das alterações;
   - comandos executados;
   - resultados;
   - pendências.
6. Não remova comentários didáticos sem justificar.

Critério de aceite:
- `make all` passa;
- `scripts/run_battery_test.sh quick` inicia corretamente;
- `scripts/summarize_log.py` interpreta o CSV gerado.
