# Plano de teste

## Objetivo

Medir a autonomia de uma power bank alimentando um Raspberry Pi 5 sob cargas controladas de CPU, memória, vídeo e, quando possível, GPU.

## Perfis

- `quick`: carga leve para verificar se tudo funciona.
- `balanced`: Carga controlada de CPU e memória (via `battery_logger`).
- `video`: Carga de CPU e memória + codificação de vídeo com `ffmpeg`.
- `full`: Carga de CPU, memória, `ffmpeg` + carga gráfica com `glmark2`.

## Como as cargas são geradas

- CPU: o `battery_logger` cria threads internas que mantêm a FPU ocupada com `sin()` e `sqrt()` em loop.
- Memória: o `battery_logger` aloca um bloco configurável e faz leituras/escritas contínuas com stride de 64 bytes.
- Vídeo: o `ffmpeg` gera `testsrc2` sintético e codifica em H.264 por software com `libx264`.
- GPU: o script tenta `glmark2-es2-drm`, depois `glmark2-es2-wayland`, depois `glmark2`; se nenhuma variante funcionar, o perfil `full` continua sem GPU ativa e registra aviso.

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
- **Atenção:** O perfil `full` só mede GPU se alguma variante do `glmark2` puder ser executada. A variante `glmark2-es2-drm` é priorizada para funcionar em KMS/DRM e pode ser adequada para SSH/headless; Wayland ou a variante genérica dependem do ambiente gráfico disponível.
- Se quiser medir cenário real com câmera, substitua ou adicione uma carga com `rpicam-vid`/`libcamera` conforme a câmera instalada.
- O desligamento abrupto pode corromper o cartão SD. O programa usa `fsync()` para preservar o log, mas isso não elimina totalmente o risco.
