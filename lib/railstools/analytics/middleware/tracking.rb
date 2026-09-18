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
            ip: requisicao.ip
          )
        rescue StandardError => e
          Analytics.warn("não consegui medir a requisição: #{e.class} #{e.message}")
        end

        def rastreavel?(requisicao, status, headers)
          return false unless requisicao.get?
          return false unless status.to_i == 200
          return false unless html?(headers)

          config = Analytics.config
          return false if config.ignore_path?(requisicao.path)
          return false if config.ignore_user_agent?(requisicao.user_agent)

          true
        end

        def html?(headers)
          tipo = headers["content-type"] || headers["Content-Type"]
          tipo.to_s.include?("text/html")
        end
      end
    end
  end
end
