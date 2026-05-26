# Plano de teste

## Objetivo

Medir a autonomia de uma power bank alimentando um Raspberry Pi 5 sob cargas controladas de CPU, memória, vídeo e, quando possível, GPU.

## Perfis

- `quick`: carga leve para verificar se tudo funciona.
- `balanced`: Carga controlada de CPU e memória com `stress-ng`.
- `video`: Carga de CPU e memória com `stress-ng` + codificação de vídeo com `ffmpeg`.
- `full`: Carga de CPU, memória, `ffmpeg` + carga gráfica com `glmark2`. **Requer ambiente de desktop.**

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
- **Atenção:** O perfil `full` requer a execução a partir de um terminal dentro do ambiente de desktop do Raspberry Pi OS (ou via VNC), pois o `glmark2` precisa de um servidor gráfico. A execução via SSH não funcionará para este perfil.
- Se quiser medir cenário real com câmera, substitua ou adicione uma carga com `rpicam-vid`/`libcamera` conforme a câmera instalada.
- O desligamento abrupto pode corromper o cartão SD. O programa usa `fsync()` para preservar o log, mas isso não elimina totalmente o risco.
