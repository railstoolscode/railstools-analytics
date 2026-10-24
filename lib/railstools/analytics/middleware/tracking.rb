# frozen_string_literal: true

module Railstools
  module Analytics
    # O middleware que conta o pageview.
    #
    # O MÓDULO NÃO SE CHAMA `Rack`, E ISSO NÃO É ESTILO
    # -------------------------------------------------
    # `Railstools::Analytics::Rack` sombreia o Rack de verdade dentro de todo este namespace:
    # qualquer linha escrevendo `Rack::Request` sem os dois-pontos iniciais acharia o nosso
    # módulo, e o erro apareceria em outro arquivo, muito depois. A casca `::Rack::` funciona e
    # é exatamente o tipo de coisa que alguém esquece no próximo arquivo. `Middleware` resolve
    # na raiz.
    module Middleware
      #
      # DUAS REGRAS QUE NÃO PODEM SER QUEBRADAS
      # ---------------------------------------
      # 1. **Nunca derruba o app que mede.** Todo o corpo está dentro de um `rescue`: um agente
      #    de medição que estoura numa requisição do cliente é infinitamente pior que um agente
      #    que perde um pageview.
      # 2. **Nunca atrasa a resposta.** O que acontece aqui é empilhar um Hash em memória. A
      #    ida à rede é de outra thread (ver `Dispatcher`).
      #
      # O QUE NÃO É PAGEVIEW
      # --------------------
      # `GET` que devolve HTML, e só. Requisição de ativo, `POST` de formulário, chamada de API
      # e redirecionamento não são páginas vistas — contá-los infla o número e enche a lista de
      # páginas com rotas que ninguém "visitou".
      #
      # O RECORTE É DIFERENTE DO SNIPPET, E ISSO É ESPERADO
      # ---------------------------------------------------
      # Aqui se vê TODA requisição que chega ao servidor, inclusive a de robô que nunca
      # executaria JavaScript. O filtro de user-agent corta o óbvio e o servidor faz a
      # classificação de verdade, mas o número do middleware tende a ser MAIOR que o do
      # snippet para o mesmo site. Quem usa os dois junto vê o pageview duas vezes — a
      # documentação diz para escolher um.
      class Tracking
        # Prefetch não é página vista: é o navegador (ou o Turbo, ao passar o mouse num link)
        # adiantando uma página que a pessoa talvez nem abra. Contá-lo infla o número com quem
        # só passou o mouse — e, quando ela clica, a página já veio e o pageview de verdade nem
        # chega ao servidor. Cada um avisa de um jeito: `Sec-Purpose` é o padrão (Chrome, também
        # no prerender), `X-Sec-Purpose` é o do Turbo 8 (o navegador não deixa `fetch` escrever
        # `Sec-*`), `Purpose` e `X-Moz` são os antigos.
        PREFETCH_HEADERS = %w[HTTP_SEC_PURPOSE HTTP_X_SEC_PURPOSE HTTP_PURPOSE HTTP_X_MOZ].freeze

        def initialize(app)
          @app = app
        end

        # A exceção do APP sobe: engoli-la esconderia o erro de quem nos instalou, e há teste
        # provando isso. Quem não sobe é erro NOSSO — o `rescue` mora dentro de `track`, que é
        # a única parte daqui que é código nosso.
        def call(env)
          resposta = @app.call(env)
          track(env, resposta) if Analytics.enabled?
          resposta
        end

        private

        def track(env, resposta)
          status, headers, = resposta
          requisicao = ::Rack::Request.new(env)

          return unless rastreavel?(requisicao, status, headers)

          Analytics.track_pageview(
            url: requisicao.url,
            referrer: env["HTTP_REFERER"],
            user_agent: env["HTTP_USER_AGENT"],
            ip: ip_de(env, requisicao)
          )
        rescue StandardError => e
          Analytics.warn("não consegui medir a requisição: #{e.class} #{e.message}")
        end

        def rastreavel?(requisicao, status, headers)
          return false unless requisicao.get?
          return false unless status.to_i == 200
          return false unless html?(headers)
          return false if prefetch?(requisicao.env)

          config = Analytics.config
          return false if config.ignore_path?(requisicao.path)
          return false if config.ignore_user_agent?(requisicao.user_agent)

          true
        end

        def html?(headers)
          tipo = headers["content-type"] || headers["Content-Type"]
          tipo.to_s.include?("text/html")
        end

        # Ver `PREFETCH_HEADERS`.
        def prefetch?(env)
          PREFETCH_HEADERS.any? { |cabecalho| env[cabecalho].to_s.downcase.include?("prefetch") }
        end

        # O IP de quem visita, que o servidor do Analytics usa (com o navegador e o sal do dia)
        # para saber que duas páginas são da mesma pessoa. Em ordem de quem sabe mais:
        #
        # 1. **O cabeçalho configurado** (`ip_header`, ex.: CF-Connecting-IP), quando o dono do
        #    app ligou. Ele sabe que o app só é alcançado por aquele proxy; nós não sabemos.
        # 2. **O IP que o Rails já resolveu** (`action_dispatch.remote_ip`), com a lista de
        #    proxies confiáveis do PRÓPRIO app (`config.action_dispatch.trusted_proxies`).
        # 3. **O do Rack**, para app Rack sem Rails.
        #
        # POR QUE NÃO SÓ O DO RACK
        # ------------------------
        # `Rack::Request#ip` confia só em rede privada. Atrás de um proxy público — a Cloudflare,
        # um balanceador com IP público — ele devolve o IP do proxy, e TODO visitante vira o
        # mesmo punhado de IPs: o Analytics funde pessoas diferentes numa só, a contagem de
        # visitantes despenca e a duração das visitas sobe, sem nenhum erro em lugar nenhum. O
        # app de Rails já diz em quem confia; ignorar isso era o erro.
        def ip_de(env, requisicao)
          ip_do_cabecalho(env) || ip_do_rails(env) || requisicao.ip
        end

        def ip_do_cabecalho(env)
          chave = Analytics.config.ip_header_env_key
          return unless chave

          valor = env[chave].to_s.split(",").first.to_s.strip
          valor unless valor.empty?
        end

        # Um objeto `GetIp` que resolve no `to_s`, e que pode levantar `IpSpoofAttackError`
        # quando `Client-IP` e `X-Forwarded-For` discordam. Nesse caso, cai no do Rack: perder a
        # precisão do IP é melhor que perder o pageview.
        def ip_do_rails(env)
          resolvido = env["action_dispatch.remote_ip"]
          return unless resolvido

          valor = resolvido.to_s.strip
          valor unless valor.empty?
        rescue StandardError
          nil
        end
      end
    end
  end
end
