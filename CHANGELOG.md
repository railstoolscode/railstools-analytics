# Mudanças

## 0.2.0

- **IP de quem visita atrás de proxy.** O middleware usa o IP que o Rails já resolveu
  (`action_dispatch.remote_ip`, com os `trusted_proxies` do app) antes do `Rack::Request#ip`,
  que só confia em rede privada. Atrás da Cloudflare, o IP medido era o da borda dela, e
  visitantes diferentes viravam um só no Analytics.
- Opção `ip_header` (`RAILSTOOLS_ANALYTICS_IP_HEADER`), desligada por padrão, para ler o IP de um
  cabeçalho do proxy (ex.: `CF-Connecting-IP`).
- Prefetch não conta como pageview (`Sec-Purpose`, `X-Sec-Purpose` do Turbo 8, `Purpose`,
  `X-Moz`).

## 0.1.0

- Middleware Rack que conta pageview sem atrasar a resposta (lote em memória + thread de envio).
- `Railstools::Analytics.track` para evento próprio do lado do servidor.
- Helper `railstools_analytics_snippet` para quem quer o caminho do navegador.
- Sem cookie, sem identificador persistente, sem dependência fora da biblioteca padrão.
