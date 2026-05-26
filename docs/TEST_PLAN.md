# Plano de teste

## Objetivo

Medir a autonomia de uma power bank alimentando um Raspberry Pi 5 sob cargas controladas de CPU, memória, vídeo e, quando possível, GPU.

## Perfis

- `quick`: carga leve para verificar se tudo funciona.
- `balanced`: CPU + memória, sem vídeo.
- `video`: CPU + memória + codificação sintética com `ffmpeg`.
- `full`: CPU + memória + `ffmpeg` + tentativa de carga gráfica com `glmark2`.

## Procedimento recomendado

1. Carregar completamente a power bank.
2. Usar cartão SD/SSD que possa ser regravado se houver corrupção por corte abrupto de energia.
3. Instalar dependências com `scripts/install_deps.sh`.
4. Fazer um teste curto com `scripts/run_battery_test.sh quick`.
5. Rodar o teste real com `scripts/run_battery_test.sh video` ou `scripts/run_battery_test.sh full`.
6. Após o desligamento por falta de bateria, religar o Raspberry Pi e executar:

```bash
python3 scripts/summarize_log.py logs/latest/battery_test_log.csv
```

## Cuidados

- Use dissipador e cooler no Raspberry Pi 5.
- Não conecte periféricos desnecessários se quiser medir apenas o consumo do Raspberry.
- Se quiser medir cenário real com câmera, substitua ou adicione uma carga com `rpicam-vid`/`libcamera` conforme a câmera instalada.
- O desligamento abrupto pode corromper o cartão SD. O programa usa `fsync()` para preservar o log, mas isso não elimina totalmente o risco.
