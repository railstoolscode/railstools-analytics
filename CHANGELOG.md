# Mudanças

## 0.1.0

- Middleware Rack que conta pageview sem atrasar a resposta (lote em memória + thread de envio).
- `Railstools::Analytics.track` para evento próprio do lado do servidor.
- Helper `railstools_analytics_snippet` para quem quer o caminho do navegador.
- Sem cookie, sem identificador persistente, sem dependência fora da biblioteca padrão.
