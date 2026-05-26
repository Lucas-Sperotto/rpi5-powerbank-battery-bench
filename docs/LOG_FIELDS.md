# Campos do log CSV

Arquivo principal: `logs/latest/battery_test_log.csv`.

| Campo | Significado |
|---|---|
| `epoch_s` | Tempo Unix em segundos. |
| `datetime` | Data e hora local. |
| `elapsed_s` | Tempo decorrido desde o início do teste. É o campo mais importante para medir autonomia. |
| `uptime_s` | Uptime total do sistema Linux. |
| `temp_c` | Temperatura da CPU em graus Celsius. |
| `load1`, `load5`, `load15` | Carga média do sistema em 1, 5 e 15 minutos. |
| `cpu_khz` | Frequência atual aproximada da CPU 0. |
| `throttled` | Resultado de `vcgencmd get_throttled`. `0x0` é o melhor caso; valores diferentes indicam subtensão, limitação térmica ou histórico de eventos. `NA` indica que `vcgencmd` não respondeu. |
| `mem_total_kb` | Memória total detectada pelo Linux. |
| `mem_available_kb` | Memória disponível no momento do registro. |
| `swap_free_kb` | Swap livre no momento do registro. |
