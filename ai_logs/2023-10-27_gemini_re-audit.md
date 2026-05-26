# Re-auditoria de Metodologia e Riscos - Gemini Code Assist

Data: 2023-10-27

## Veredito Geral

O repositório evoluiu significativamente. As revisões anteriores corrigiram falhas de robustez no código C e no script Bash, além de terem melhorado imensamente a clareza da documentação e dos comentários. A abordagem para a carga de GPU, que agora prioriza a variante `drm` para funcionamento headless, é um excelente avanço e resolve uma das principais preocupações da auditoria inicial.

No entanto, foi identificada uma **inconsistência crítica (P0)** entre a documentação e a implementação da carga de CPU/memória. A documentação foi atualizada para mencionar o `stress-ng`, mas a implementação (corretamente) utiliza o programa `battery_logger` para essa tarefa. Corrigir essa divergência é essencial para que o usuário entenda como o benchmark realmente funciona.

---

## Achados e Recomendações Priorizadas

### P0: Risco Crítico

1.  **Inconsistência entre Documentação e Implementação da Carga de CPU/Memória**
    *   **Problema:** O `README.md` e o `docs/TEST_PLAN.md` afirmam que o `stress-ng` é usado para gerar carga de CPU, mas a implementação real utiliza exclusivamente as threads internas do programa `battery_logger` para essa finalidade. Isso cria uma confusão fundamental sobre o funcionamento do teste. A implementação via `battery_logger` é válida, mas a documentação está incorreta.
    *   **Recomendação:** Remover todas as menções ao `stress-ng` da documentação e clarificar que o `battery_logger` é o único responsável pela carga de CPU e memória.

### P1: Risco Alto

1.  **Carga de Vídeo (`ffmpeg`) Potencialmente Fraca por Padrão**
    *   **Problema:** O script `run_battery_test.sh` utiliza o preset `veryfast` para o `ffmpeg`. Este preset é otimizado para velocidade de codificação, resultando em um uso de CPU relativamente baixo. Isso pode subestimar o consumo de energia em um cenário de vídeo, enfraquecendo a distinção entre os perfis `balanced` e `video`.
    *   **Recomendação:** Alterar o preset padrão do `ffmpeg` para `medium`. Este preset oferece um equilíbrio muito melhor, exigindo um esforço de CPU significativamente maior e mais representativo de uma carga de codificação real.

### P2: Risco Médio

1.  **Verificação de Dependências Essenciais Ausente**
    *   **Problema:** O script não possui uma verificação inicial (pre-flight check) para dependências essenciais como `gcc`, `make` e `python3`. Se um usuário clonar o repositório e rodar o teste sem antes executar `install_deps.sh`, o script pode falhar no meio do caminho de forma não intuitiva (ex: ao tentar compilar ou gerar o resumo).
    *   **Recomendação:** Adicionar uma função `check_dependencies` no início do `run_battery_test.sh` que valide a existência das ferramentas essenciais e aborte a execução com uma mensagem clara se algo estiver faltando.

2.  **Documentação sobre Carga de GPU Headless Imprecisa**
    *   **Problema:** O `README.md` afirma que a carga de GPU é "ignorada automaticamente" em ambientes headless. Isso não é totalmente preciso, pois o script agora tenta, de forma inteligente, usar `glmark2-es2-drm`, que *pode* funcionar em modo headless. A documentação não reflete essa melhoria.
    *   **Recomendação:** Atualizar o `README.md` para explicar que o script prioriza uma versão do `glmark2` compatível com headless e que a carga só é ignorada se essa tentativa falhar.

---

## Arquivos Afetados e Sugestões de Mudança

- `README.md`
- `docs/TEST_PLAN.md`
- `scripts/run_battery_test.sh`

*(As sugestões de mudança foram fornecidas na resposta anterior)*

---

## Comandos que Deveriam ser Executados no Raspberry Pi

1.  **Aplicar as alterações sugeridas** nos arquivos `README.md`, `docs/TEST_PLAN.md` e `scripts/run_battery_test.sh`.

2.  **Testar a nova verificação de dependências (P2):**
    ```bash
    # Renomeie temporariamente um executável essencial
    sudo mv /usr/bin/gcc /usr/bin/gcc_bak

    # Tente rodar o script. Ele deve falhar com uma mensagem de erro clara.
    ./scripts/run_battery_test.sh quick

    # Restaure o executável
    sudo mv /usr/bin/gcc_bak /usr/bin/gcc
    ```

3.  **Verificar o aumento da carga do `ffmpeg` (P1):**
    ```bash
    # Execute o teste de vídeo por um curto período
    ./scripts/run_battery_test.sh video &
    BENCH_PID=$!

    # Monitore o uso de CPU por 30 segundos. A carga nos cores deve ser visivelmente maior
    # do que seria com o preset 'veryfast'.
    htop -d 1

    # Encerre o teste
    kill $BENCH_PID
    ```