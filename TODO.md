# TODO

## P0

- Testar no Raspberry Pi 5 real com `scripts/run_battery_test.sh quick`.
- Confirmar se `vcgencmd get_throttled` está disponível.
- Confirmar qual binário `glmark2` existe no sistema: `glmark2`, `glmark2-es2-drm` ou `glmark2-es2-wayland`.

## P1

- Adicionar suporte opcional a câmera real com `rpicam-vid`/`libcamera`, quando houver câmera conectada.
- Criar `RESULTS.md` automático a partir do CSV.
- Adicionar coleta de consumo externo caso haja medidor USB-C compatível.

## P2

- Gerar gráficos de temperatura, frequência, memória disponível e duração.
- Adicionar perfis específicos: `camera`, `server`, `desktop`, `headless`.
- Criar GitHub Actions apenas para compilar o código C em Linux.
