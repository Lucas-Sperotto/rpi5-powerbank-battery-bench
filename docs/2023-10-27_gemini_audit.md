# Auditoria de Metodologia e Riscos - Gemini Code Assist

Data: 2023-10-27

## Veredito Geral

O projeto possui uma base metodológica sólida para medir a autonomia da bateria, utilizando corretamente o `elapsed_s` como métrica principal e demonstrando consciência sobre riscos importantes como superaquecimento e corrupção de dados.

No entanto, a auditoria revelou **falhas críticas (P0)** na forma como as cargas de trabalho (workloads) são geradas, especialmente para CPU, memória e GPU. Sem as correções sugeridas, há um risco significativo de que os testes não estressem o hardware como pretendido, o que pode invalidar os resultados dos perfis `balanced` e `full`.

---

## Achados e Recomendações Priorizadas

### P0: Risco Crítico

1.  **Risco de Ausência de Carga na GPU (Perfil `full`)**
    *   **Problema:** O `glmark2` é usado para estressar a GPU, mas ele requer um ambiente gráfico (servidor X11 ou Wayland) para funcionar. Se o script de teste for executado em uma sessão SSH padrão (headless), o `glmark2` falhará, e nenhuma carga de GPU será aplicada, invalidando o propósito do perfil `full`.
    *   **Recomendação:** Documentar explicitamente a necessidade de um desktop e adicionar uma verificação no script para abortar a execução do perfil `full` se o ambiente gráfico não estiver presente.

2.  **Risco de Ausência de Carga de CPU e Memória (Perfis `balanced`, `video`, `full`)**
    *   **Problema:** A documentação menciona perfis com carga de "CPU + memória", mas não especifica qual ferramenta gera essa carga de forma controlada. Se a carga depender apenas de `ffmpeg` ou `glmark2`, o perfil `balanced` pode não gerar estresse algum, e a carga nos outros perfis será inconsistente.
    *   **Recomendação:** Integrar uma ferramenta dedicada como `stress-ng` para aplicar uma carga de CPU e memória padronizada e configurável em todos os perfis relevantes.

### P1: Risco Alto

1.  **Risco de Carga de Vídeo Ineficaz (Perfis `video`, `full`)**
    *   **Problema:** O comando `ffmpeg` pode gerar uma carga muito baixa se os parâmetros não forem escolhidos para maximizar o uso de recursos. Por exemplo, usar uma fonte de teste simples com um codec rápido pode subutilizar a CPU ou o codificador de hardware.
    *   **Recomendação:** Ajustar o comando `ffmpeg` para garantir uma carga sustentada, por exemplo, forçando o uso de um preset de codificação lento (`-preset slow`) para estressar a CPU.

2.  **Dependência de Ambiente Gráfico Não Documentada**
    *   **Problema:** O `TEST_PLAN.md` não informa ao usuário que o perfil `full` só funciona em um ambiente de desktop. Isso leva a execuções falhas e resultados incorretos.
    *   **Recomendação:** Atualizar a documentação com os pré-requisitos de cada perfil.

### P2: Risco Médio

1.  **Desgaste do Cartão SD por Escritas Excessivas**
    *   **Problema:** O logger grava dados periodicamente. Em testes de muitas horas, uma frequência de escrita muito alta (ex: 1 segundo) pode contribuir para o desgaste prematuro do cartão SD.
    *   **Recomendação:** Documentar a frequência de log e, se possível, torná-la um parâmetro configurável no script `run_battery_test.sh`.

2.  **Falta de Verificação de Dependências**
    *   **Problema:** O script de teste não verifica se as ferramentas necessárias (`ffmpeg`, `glmark2`, etc.) estão instaladas antes de iniciar. Um teste pode começar e falhar no meio do caminho se uma dependência estiver faltando.
    *   **Recomendação:** Adicionar um "pre-flight check" no início do `run_battery_test.sh` para validar a existência de todos os comandos necessários.

---

## Recomendações Testáveis

1.  **(P0) Adicionar carga de CPU/Memória com `stress-ng`:**
    *   Modificar `scripts/run_battery_test.sh` para usar `stress-ng` nos perfis `balanced`, `video` e `full`.
    *   **Teste:** Execute `scripts/run_battery_test.sh balanced` e verifique com `htop` se há processos `stress-ng` consumindo CPU e memória.

2.  **(P0/P1) Tornar a carga da GPU explícita e testável:**
    *   Atualizar `docs/TEST_PLAN.md` para declarar que o perfil `full` requer um ambiente de desktop.
    *   No `run_battery_test.sh`, antes de executar `glmark2`, verificar se a variável de ambiente `DISPLAY` está definida.
    *   **Teste:** Tente executar `scripts/run_battery_test.sh full` a partir de uma sessão SSH. O script deve falhar com uma mensagem de erro.

3.  **(P1) Melhorar o comando `ffmpeg`:**
    *   Usar um comando que garanta carga sustentada, como: `ffmpeg -f lavfi -i testsrc=duration=99999:size=1280x720:rate=30 -c:v libx264 -preset slow -f null - &`
    *   **Teste:** Execute o comando `ffmpeg` isoladamente e monitore o uso da CPU com `htop`.

4.  **(P2) Adicionar verificação de dependências:**
    *   No início de `run_battery_test.sh`, adicionar um loop que verifica a existência dos comandos (`vcgencmd`, `stress-ng`, `ffmpeg`, `glmark2`).
    *   **Teste:** Renomeie temporariamente um executável (ex: `sudo mv /usr/bin/ffmpeg /usr/bin/ffmpeg_bak`) e rode o script. Ele deve falhar com uma mensagem de erro apropriada.