# Fluxo de cooperação com Codex, Claude e Gemini

## Papel sugerido de cada agente

- **Gemini Code Assist**: revisão ampla, checagem de documentação, identificação de inconsistências, sugestões de cenários adicionais e inspeção de logs. Como não consome seus tokens pagos, use para auditoria repetitiva e análise de arquivos grandes, mas peça respostas objetivas e em formato de patch/lista.
- **Codex**: implementação, ajustes de scripts Bash/C, criação de testes, padronização de CLI e validação local com `make` e execução curta.
- **Claude Code**: organização do repositório, melhoria dos comentários, clareza do README, refatoração didática, documentação das decisões e explicação dos riscos técnicos.

## Regra de ouro

Nenhum agente deve apenas “melhorar genericamente”. Cada agente deve produzir uma alteração rastreável, com objetivo, arquivos alterados, comandos executados, resultado e pendências.

## Arquivos de controle sugeridos

- `docs/TEST_PLAN.md`
- `docs/LOG_FIELDS.md`
- `docs/AI_WORKFLOW.md`
- `ai_logs/YYYY-MM-DD_agente_tarefa.md`
- `TODO.md`
- `RESULTS.md`

## Ciclo sugerido

1. Gemini revisa a proposta e aponta riscos.
2. Codex implementa correções objetivas.
3. Claude organiza comentários, README e didática.
4. Gemini audita novamente.
5. Você executa no Raspberry Pi e salva logs em `logs/`.
6. Codex/Claude ajudam a gerar `RESULTS.md` com análise dos CSVs.
