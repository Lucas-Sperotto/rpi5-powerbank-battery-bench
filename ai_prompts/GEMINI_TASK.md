# Prompt para Gemini Code Assist

Você está trabalhando no repositório `rpi5-powerbank-battery-bench`.

Objetivo: auditar o benchmark de autonomia de Raspberry Pi 5 com power bank, procurando falhas metodológicas, riscos e lacunas de documentação.

Tarefas:
1. Não reescreva tudo. Faça uma auditoria objetiva.
2. Verifique se o repositório mede corretamente autonomia por meio de `elapsed_s` no CSV.
3. Verifique se há risco de o teste não acionar de fato CPU, memória, vídeo ou GPU.
4. Aponte problemas de segurança, corrupção de SD, excesso de escrita, superaquecimento ou dependência de ambiente gráfico.
5. Sugira melhorias priorizadas como P0, P1 e P2.
6. Salve o resultado em `ai_logs/YYYY-MM-DD_gemini_audit.md`.

Formato desejado:
- Veredito geral;
- Achados P0/P1/P2;
- Arquivos afetados;
- Recomendações testáveis;
- Comandos que deveriam ser executados no Raspberry Pi.
