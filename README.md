# rpi5-powerbank-battery-bench

Benchmark simples e reprodutível para medir quanto tempo um Raspberry Pi 5 fica ligado em uma power bank sob carga controlada.

O projeto combina:

- programa em C para log confiável, carga de CPU e carga de memória;
- script Bash para orquestrar perfis de teste;
- carga de vídeo sintética com `ffmpeg`;
- tentativa opcional de carga gráfica com `glmark2`;
- resumo automático do CSV final.

## Por que fazer assim?

O Raspberry Pi 5 tem CPU Arm Cortex-A76 quad-core, GPU VideoCore VII, suporte a OpenGL ES e Vulkan e decodificação HEVC 4Kp60. Portanto, um teste apenas de CPU não representa todos os cenários de uso. Este repositório separa CPU, memória, vídeo e GPU para que você consiga comparar perfis.

## Instalação

No Raspberry Pi OS:

```bash
sudo apt update
sudo apt install -y git

git clone https://github.com/SEU_USUARIO/rpi5-powerbank-battery-bench.git
cd rpi5-powerbank-battery-bench

./scripts/install_deps.sh
make all
```

## Teste rápido

```bash
./scripts/run_battery_test.sh quick
```

Acompanhe o CSV:

```bash
tail -f logs/latest/battery_test_log.csv
```

## Teste recomendado para autonomia

Para um teste razoavelmente pesado, mas ainda controlado:

```bash
./scripts/run_battery_test.sh video
```

Para tentar usar CPU, memória, vídeo e GPU:

```bash
./scripts/run_battery_test.sh full
```

O perfil `full` depende de ambiente gráfico/DRM funcional para `glmark2`. Em Raspberry headless, ele pode falhar ou simplesmente não gerar carga gráfica real.

## Perfis disponíveis

| Perfil | CPU | Memória | Vídeo `ffmpeg` | GPU `glmark2` |
|---|---:|---:|---:|---:|
| `quick` | 2 threads | 512 MB | não | não |
| `balanced` | 4 threads | 1024 MB | não | não |
| `video` | 4 threads | 1024 MB | sim | não |
| `full` | 4 threads | 2048 MB | sim | sim |

Você pode sobrescrever variáveis:

```bash
INTERVAL=10 CPU_THREADS=4 MEM_MB=2048 ./scripts/run_battery_test.sh video
```

## Depois que a bateria acabar

Quando a power bank acabar, o Raspberry Pi vai desligar abruptamente. Depois de ligar novamente:

```bash
cd rpi5-powerbank-battery-bench
python3 scripts/summarize_log.py logs/latest/battery_test_log.csv
```

O campo mais importante é `elapsed_s`, que mostra o tempo decorrido desde o início do teste.

## Rodar no boot com systemd

Edite o arquivo de serviço:

```bash
cp systemd/battery-bench.service.template battery-bench.service
nano battery-bench.service
```

Ajuste:

- `User=pi`
- `WorkingDirectory=/home/pi/rpi5-powerbank-battery-bench`
- `ExecStart=/home/pi/rpi5-powerbank-battery-bench/scripts/run_battery_test.sh video`

Instale:

```bash
sudo cp battery-bench.service /etc/systemd/system/battery-bench.service
sudo systemctl daemon-reload
sudo systemctl enable battery-bench.service
sudo systemctl start battery-bench.service
```

Verifique:

```bash
systemctl status battery-bench.service
tail -f logs/latest/battery_test_log.csv
```

## Cuidados

- Use dissipador e cooler no Raspberry Pi 5.
- Faça backup ou use um cartão SD descartável para o teste, pois o desligamento abrupto pode corromper o sistema de arquivos.
- O programa usa `fsync()` a cada linha para reduzir a perda de log, mas isso não elimina totalmente o risco.
- Uma power bank pode anunciar muitos watts, mas não entregar o perfil ideal em 5 V para o Raspberry Pi 5. Observe o campo `throttled`.

## Estrutura

```text
.
├── src/battery_logger.c
├── scripts/install_deps.sh
├── scripts/run_battery_test.sh
├── scripts/summarize_log.py
├── systemd/battery-bench.service.template
├── docs/LOG_FIELDS.md
├── docs/TEST_PLAN.md
├── docs/AI_WORKFLOW.md
├── ai_prompts/
└── TODO.md
```

## Criar o repositório no GitHub

Com GitHub CLI:

```bash
git init
git add .
git commit -m "feat: add Raspberry Pi 5 battery benchmark harness"
gh repo create rpi5-powerbank-battery-bench --public --source=. --remote=origin --push
```

Sem GitHub CLI, crie um repositório vazio no GitHub e depois rode:

```bash
git remote add origin https://github.com/SEU_USUARIO/rpi5-powerbank-battery-bench.git
git branch -M main
git push -u origin main
```
