# TODO

## Resolvido nesta preparação final

- [x] Alinhar documentação de carga CPU/memória com a implementação real via `battery_logger`.
- [x] Substituir o preset padrão de vídeo por `medium`.
- [x] Documentar prioridade de GPU headless: `glmark2-es2-drm`, `glmark2-es2-wayland`, `glmark2`.
- [x] Adicionar pre-flight check para dependências essenciais e workloads por perfil.

## Hardware / execução real

- [ ] Testar no Raspberry Pi 5 real com `scripts/run_battery_test.sh quick`.
- [ ] Testar no Raspberry Pi 5 real com `scripts/run_battery_test.sh video`.
- [ ] Testar no Raspberry Pi 5 real com `scripts/run_battery_test.sh full`.
- [ ] Confirmar se `vcgencmd get_throttled` está disponível e retorna valores corretos.
- [ ] Confirmar qual binário `glmark2` existe e executa corretamente no sistema: `glmark2-es2-drm`, `glmark2-es2-wayland` ou `glmark2`.
- [ ] Registrar o modelo e capacidade (Wh) da power bank usada no teste.

## Funcionalidades

- [ ] Adicionar suporte opcional a câmera com `rpicam-vid`/`libcamera` como carga adicional.
- [ ] Adicionar coleta de consumo externo caso haja medidor USB-C compatível (ex: `riden`, `um25c`).
- [ ] Adicionar detecção automática da memória disponível para evitar OOM nos perfis pesados.
- [ ] Criar perfis adicionais: `camera`, `server` (carga de rede), `headless` (sem GPU).

## Análise e visualização

- [ ] Gerar gráficos de temperatura, frequência, memória disponível e duração (matplotlib ou gnuplot).
- [ ] Criar `RESULTS.md` após o primeiro ensaio real, com tabela de comparação entre power banks.
- [ ] Criar relatório automático em Markdown após cada teste com `summarize_log.py`.

## Documentação

- [ ] Adicionar exemplos reais de resultados com diferentes power banks em `RESULTS.md`.
- [ ] Documentar os valores típicos do campo `throttled` e o que cada bit significa.
- [ ] Criar GitHub Actions para compilar o código C em Linux (CI mínimo).
- [ ] Adicionar suporte a diferentes modelos de Raspberry Pi (3B+, 4B, 5).
