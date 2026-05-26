# Revisão de documentação — Claude Code (2026-05-25)

## Objetivo

Tornar o repositório didático e autossuficiente para alunos e pesquisadores: quem clonar, instalar dependências e rodar `quick` deve conseguir interpretar o resultado sem consultar fontes externas.

## Arquivos modificados

### `README.md`

**Adicionado: seção "Pré-requisitos"**
Motivo: o repositório não documentava hardware mínimo (RPi 5), versão do OS (Bookworm 64-bit), capacidade do cartão SD nem requisitos de saída da power bank. Sem isso, um iniciante pode tentar rodar em hardware incompatível.

**Adicionado: seção "Entendendo as cargas"**
Motivo: a tabela de perfis mostrava *o que* cada perfil ativa, mas não *por que* as cargas são diferentes. A maior lacuna era a confusão entre:
- carga de CPU (FPU em loop com sin/sqrt) vs. carga de memória (stride-64 na DRAM)
- carga de vídeo (`ffmpeg` com H.264 em software — padrão de acesso diferente do stress-ng)
- carga de GPU (`glmark2` — único perfil que estresa a VideoCore VII, não a CPU)

**Melhorado: seção "Depois que a bateria acabar"**
Motivo: o README apenas dizia para rodar `summarize_log.py` sem mostrar o que esperar. Adicionado exemplo de saída real e guia de interpretação dos campos mais importantes (`Duração`, `Temperatura máxima`, `throttled`).

**Atualizado: seção "Estrutura"**
Motivo: a estrutura listada estava desatualizada; faltavam `ai_logs/` e `ai_prompts/`, e os arquivos não tinham descrição inline.

### `src/battery_logger.c`

Adicionados três blocos de comentário explicando o *porquê* de decisões de implementação:

- **`cpu_worker` (antes da função)**: explica que `sin(x)*sqrt(x)` + `volatile` impede que o compilador elimine o laço por otimização — escolha deliberada para manter a FPU ocupada.
- **laço interno de `memory_worker`**: explica que o stride de 64 bytes (tamanho de uma linha de cache) força leituras na DRAM que não cabem no cache L3.
- **`sync_log_fd`**: explica que `fsync()` a cada linha é essencial em testes de bateria onde o desligamento abrupto é o cenário esperado.

### `scripts/run_battery_test.sh`

Adicionados dois blocos de comentário:

- **`start_ffmpeg_video`**: explica `testsrc2` (gerador sintético, sem disco), `-f null -` (descarta saída), e o papel do `while` loop para carga contínua.
- **`start_gpu_workload`**: explica as três variantes de binário do glmark2 (`drm`, `wayland`, genérico) e por que priorizamos `drm` para funcionar headless.

### `TODO.md`

Consolidadas as duas seções sobrepostas (P0/P1/P2 e "Próximos passos") em uma estrutura única com checkboxes, agrupada por área temática: Hardware, Funcionalidades, Análise e Documentação.

## O que foi mantido sem alteração

- `scripts/install_deps.sh` — curto e suficiente para seu propósito.
- `scripts/summarize_log.py` — código claro, saída legível.
- `docs/LOG_FIELDS.md` — já documentava todos os campos com precisão.
- `docs/TEST_PLAN.md` — recentemente atualizado pela revisão do Gemini.
- `docs/AI_WORKFLOW.md` — descreve o fluxo de colaboração entre agentes com clareza.

## Pendências

- Validar no hardware real (Raspberry Pi 5) que o `quick` funciona ponta a ponta.
- Confirmar binário correto do `glmark2` no sistema alvo.
- Adicionar exemplos reais de saída do `summarize_log.py` em `RESULTS.md` após o primeiro teste real.
- Rever a seção "throttled" no README quando houver dados reais de `vcgencmd` para ilustrar com valores concretos.
