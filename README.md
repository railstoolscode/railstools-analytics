# railstools-analytics

Agente do [Analytics](https://analytics.railstools.com.br): mede audiência de uma aplicação
Ruby e manda para a sua instalação.

**Sem cookie e sem identificador persistente.** Quem identifica o visitante é o servidor, a
partir de IP, user-agent e domínio, com um sal que gira todo dia e é apagado — não há banner de
consentimento a pedir. Ruby puro, sem extensão nativa e sem dependência fora da biblioteca
padrão.

## Instalação

```ruby
gem "railstools-analytics"
```

```ruby
# config/initializers/railstools_analytics.rb
Railstools::Analytics.configure do |config|
  config.site = "seusite.com.br"
  config.ingest_key = ENV["RAILSTOOLS_ANALYTICS_KEY"]
  config.endpoint = "https://analytics.railstools.com.br"
end
```

Em Rails o middleware entra sozinho. Sem `site` ou sem `ingest_key` o agente fica **desligado**
e não faz nada — um agente que liga sem para onde mandar só enche o log.

## Os dois caminhos, e por que escolher um

| | O middleware (esta gem) | O snippet do navegador |
|---|---|---|
| Vê | toda requisição que chega ao servidor | só quem executa JavaScript |
| Navegação de SPA | não | sim |
| Taxa de rejeição e duração | aproximadas | precisas |
| Robô | filtrado por user-agent | quase não chega |
| Bloqueador de anúncio | não alcança | pode bloquear |

**Usar os dois ao mesmo tempo conta o pageview duas vezes.** Escolha um. O middleware é o
caminho certo para app Rails tradicional; o snippet, para SPA e site estático.

Para o snippet, no layout:

```erb
<%= railstools_analytics_snippet %>
```

## Evento próprio

Para o que o navegador não sabe — assinatura confirmada por webhook, job que terminou,
conversão do lado do servidor:

```ruby
Railstools::Analytics.track(
  "Assinatura",
  url: "https://seusite.com.br/assinatura",
  props: { plano: "growth" }
)
```

## Como ele não atrapalha o seu app

São duas promessas, as duas com teste:

- **Nunca derruba.** Todo o middleware está dentro de um `rescue`. Um agente de medição que
  estoura numa requisição do cliente é pior que um agente que perde um pageview.
- **Nunca atrasa.** A requisição só empilha um Hash em memória; a ida à rede é de outra thread.
  A fila tem teto e **descarta** quando o Analytics está fora do ar — crescer sem limite mataria
  o seu app por falta de memória, e perder pageview de uma indisponibilidade é o preço certo.

## Configuração

| Opção | Padrão | Para quê |
|---|---|---|
| `site` | `RAILSTOOLS_ANALYTICS_SITE` | O domínio medido |
| `ingest_key` | `RAILSTOOLS_ANALYTICS_KEY` | A chave de escrita daquele site |
| `endpoint` | `https://analytics.railstools.com.br` | A sua instalação |
| `flush_interval` | 5 s | De quanto em quanto o lote sai |
| `max_batch` | 200 | Tamanho do lote |
| `ignore_paths` | ativo, healthcheck, favicon… | O que nunca é pageview |
| `ignore_user_agents` | robôs comuns | Quem não é gente |
| `ip_header` | `RAILSTOOLS_ANALYTICS_IP_HEADER` (desligado) | Cabeçalho com o IP de quem visita, ex.: `CF-Connecting-IP` |

## O IP de quem visita, atrás de proxy

O servidor do Analytics junta as páginas de uma mesma pessoa pelo IP e pelo navegador (com o sal
do dia). Se o IP medido for o de um proxy, pessoas diferentes viram uma só, sem erro em lugar
nenhum: a contagem de visitantes cai e a duração das visitas sobe.

O middleware usa, nesta ordem:

1. o cabeçalho de `ip_header`, quando você liga;
2. o IP que o Rails já resolveu (`request.remote_ip`), que respeita
   `config.action_dispatch.trusted_proxies`;
3. o `Rack::Request#ip`, para app Rack sem Rails.

**Atrás da Cloudflare (ou de outro proxy com IP público)**, diga ao Rails em quem confiar, com
as faixas publicadas em https://www.cloudflare.com/ips/:

```ruby
# config/application.rb
config.action_dispatch.trusted_proxies =
  ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_RANGES.map { IPAddr.new(_1) }
```

Ou ligue o `ip_header`: `RAILSTOOLS_ANALYTICS_IP_HEADER=CF-Connecting-IP`. **Só faça isso se o
app for alcançado apenas pela Cloudflare** (firewall fechado para o resto); do contrário, qualquer
um manda o cabeçalho com o IP que quiser. Com Kamal, o kamal-proxy só repassa o
`X-Forwarded-For` com `proxy.forward_headers: true`.

## Prefetch não é página vista

O middleware não conta requisição de prefetch: o `Sec-Purpose: prefetch` dos navegadores, o
`X-Sec-Purpose: prefetch` do Turbo 8 (que busca a página quando o mouse passa no link) e os
antigos `Purpose` e `X-Moz`. Quando a pessoa clica, a página já veio do prefetch, e contar o
prefetch somaria visita de quem só passou o mouse.

## Licença

MIT.
