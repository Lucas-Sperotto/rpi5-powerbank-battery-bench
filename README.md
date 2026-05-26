# rpi5-powerbank-battery-bench

Benchmark simples e reprodutível para medir quanto tempo um Raspberry Pi 5 fica ligado em uma power bank sob carga controlada.

O projeto combina:

- programa em C para log confiável, carga de CPU e carga de memória;
- script Bash para orquestrar perfis de teste;
- carga de vídeo sintética com `ffmpeg`;
- tentativa opcional de carga gráfica com `glmark2`;
- resumo automático do CSV final.

## Pré-requisitos

| Item | Requisito |
| --- | --- |
| Hardware | Raspberry Pi 5 (4 GB ou 8 GB recomendado) |
| Sistema operacional | Raspberry Pi OS 64-bit Bookworm (versão mais recente) |
| Armazenamento | Cartão SD ≥ 16 GB ou SSD via adaptador USB-C |
| Power bank | Saída USB-C PD ≥ 27 W (5 V / 5 A) para alimentar o Raspberry Pi 5 adequadamente |
| Acesso | Terminal local, SSH ou VNC; para o perfil `full` com GPU, é necessário ambiente gráfico |

## Por que fazer assim?

O Raspberry Pi 5 tem CPU Arm Cortex-A76 quad-core, GPU VideoCore VII, suporte a OpenGL ES e Vulkan e decodificação HEVC 4Kp60. Um teste apenas de CPU não representa todos os cenários de uso. Este repositório separa CPU, memória, vídeo e GPU em perfis distintos para que você possa comparar o impacto de cada tipo de carga na autonomia.

## Entendendo as cargas

Cada tipo de carga estresa um subsistema diferente do hardware. Entender a diferença ajuda a interpretar os resultados:

### Carga de CPU (`stress-ng` + threads do `battery_logger`)

O programa `battery_logger` é o responsável pela carga de CPU. Ele cria N threads (configurável por perfil) que calculam `sin(x) * sqrt(x)` em um loop contínuo. Essas operações usam a unidade de ponto flutuante (FPU) de cada núcleo A76 sem parar — o compilador não consegue eliminá-las por otimização porque o resultado acumula em uma variável `volatile`. O efeito é manter os núcleos em frequência máxima e consumo máximo de energia na CPU.

### Carga de memória (interna do `battery_logger`)

Uma thread aloca X MB de memória alinhados a página de 4 KB e percorre o buffer de 64 em 64 bytes (tamanho exato de uma linha de cache). Isso força leituras e escritas na DRAM que não cabem no cache L3 (4 MB no A76), medindo a largura de banda real da memória RAM e o consumo associado.

### Carga de vídeo via `ffmpeg`

O `ffmpeg` gera um vídeo colorido sintético (`testsrc2`, sem ler nenhum arquivo de disco) e o codifica em H.264 em software (`libx264`). Diferente das operações matemáticas simples do `stress-ng`, a codificação H.264 usa padrões de acesso de memória complexos — estimativa de movimento entre quadros, transformada DCT e codificação de entropia. A saída é descartada (`-f null -`): o objetivo é consumo de CPU em padrão de mídia real, não armazenar vídeo.

### Carga gráfica via `glmark2`

O `glmark2` renderiza cenas 3D (geometria, shaders, texturas) na GPU VideoCore VII. Diferente das outras cargas, ele **não estresa diretamente a CPU**: utiliza shaders de vértice e fragmento, amostrador de textura e a interface de memória dedicada à GPU. É o único perfil que mede o consumo do subsistema gráfico. O script prioriza a versão `glmark2-es2-drm`, que pode funcionar em modo headless (sem desktop), tornando o perfil `full` mais robusto.

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

Execute um teste curto para verificar se tudo funciona antes do teste real de autonomia:

```bash
./scripts/run_battery_test.sh quick
```

Acompanhe o CSV em tempo real:

```bash
tail -f logs/latest/battery_test_log.csv
```

Para encerrar manualmente: `Ctrl+C`. O resumo é gerado automaticamente ao encerrar.

## Teste recomendado para autonomia

Para um teste representativo com CPU, memória e codificação de vídeo:

```bash
./scripts/run_battery_test.sh video
```

Para tentar usar CPU, memória, vídeo e GPU simultaneamente:

```bash
./scripts/run_battery_test.sh full
```

O perfil `full` requer ambiente gráfico funcional (Wayland ou KMS/DRM) para o `glmark2`. Em ambientes headless via SSH sem servidor gráfico, a carga de GPU é ignorada automaticamente e um aviso é registrado em `logs/latest/warnings.log`.

## Perfis disponíveis

| Perfil | CPU | Memória | Vídeo `ffmpeg` | GPU `glmark2` |
|---|---:|---:|---:|---:|
| `quick` | 2 threads | 512 MB | não | não |
| `balanced` | 4 threads | 1024 MB | não | não |
| `video` | 4 threads | 1024 MB | sim | não |
| `full` | 4 threads | 2048 MB | sim | sim |

Você pode sobrescrever qualquer variável do perfil sem editar o script:

```bash
INTERVAL=10 CPU_THREADS=4 MEM_MB=2048 ./scripts/run_battery_test.sh video
```

## Depois que a bateria acabar

Quando a power bank acabar, o Raspberry Pi desliga abruptamente. Após religar:

```bash
cd rpi5-powerbank-battery-bench
python3 scripts/summarize_log.py logs/latest/battery_test_log.csv
```

Saída esperada (valores de exemplo):

```text
Resumo do teste
================
Arquivo: logs/latest/battery_test_log.csv
Primeiro registro: 2026-05-25 21:00:00
Último registro:   2026-05-25 23:47:30
Duração: 2h 47min 30s (10050 s)
Registros: 335
Temperatura inicial: 42.50 °C
Temperatura final:   61.80 °C
Temperatura máxima:  63.20 °C
Última frequência CPU: 2400000 kHz
Último throttled: 0x0
Nenhum throttled diferente de 0x0 encontrado no CSV.
```

**Como interpretar:**

- **Duração** — autonomia total da power bank naquele perfil. Compare entre perfis para ver o impacto de cada carga.
- **Temperatura máxima** — acima de 80 °C pode indicar throttling térmico; verifique se o cooler está funcionando.
- **throttled** — `0x0` é o melhor caso (sem limitação). Outros valores indicam subtensão (`0x50005`), throttling térmico (`0xa000a`) ou histórico de eventos. Veja detalhes completos em [`docs/LOG_FIELDS.md`](docs/LOG_FIELDS.md).

## Rodar no boot com systemd

Para que o teste comece automaticamente quando o Raspberry Pi ligar (útil para testes de autonomia sem monitor):

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

- Use dissipador e cooler no Raspberry Pi 5; sem resfriamento adequado, o throttling térmico reduz a carga e invalida a comparação entre perfis.
- Faça backup ou use um cartão SD descartável: o desligamento abrupto por falta de bateria pode corromper o sistema de arquivos.
- O programa usa `fsync()` após cada linha de log para minimizar a perda de dados no desligamento abrupto, mas isso não elimina totalmente o risco.
- Uma power bank pode anunciar muitos watts, mas não entregar 5 V / 5 A estáveis. Se o campo `throttled` mostrar `0x50005` ou similar, a power bank pode estar com subtensão.
- Não conecte periféricos desnecessários (monitor, teclado, mouse via USB) se quiser medir apenas o consumo base do Raspberry Pi.

## Estrutura

```text
.
├── src/battery_logger.c          # programa C: log + carga de CPU e memória
├── scripts/install_deps.sh       # instala dependências via apt
├── scripts/run_battery_test.sh   # orquestra perfis de teste
├── scripts/summarize_log.py      # analisa o CSV e exibe resumo
├── systemd/battery-bench.service.template
├── docs/LOG_FIELDS.md            # descrição detalhada de cada campo do CSV
├── docs/TEST_PLAN.md             # procedimento recomendado de teste
├── docs/AI_WORKFLOW.md           # fluxo de colaboração com agentes de IA
├── ai_prompts/                   # instruções usadas para direcionar agentes de IA
├── ai_logs/                      # logs de decisões e revisões dos agentes
└── TODO.md
```
