# frozen_string_literal: true

module Railstools
  module Analytics
    # A ligação com o Rails.
    #
    # O middleware entra sozinho, e **no fim da pilha**: ele precisa ver o status e o
    # `Content-Type` da resposta pronta para saber se aquilo foi uma página HTML de verdade.
    # Inserido no topo, veria a resposta antes de qualquer coisa tê-la definido.
    #
    # Fica DEPOIS do `ActionDispatch::Executor` porque ele não deve rodar fora do contexto de
    # recarga do Rails em desenvolvimento.
    class Railtie < ::Rails::Railtie
      initializer "railstools_analytics.middleware" do |app|
        app.middleware.use Railstools::Analytics::Middleware::Tracking
      end

      initializer "railstools_analytics.logger" do
        config.after_initialize do
          Analytics.config.logger ||= ::Rails.logger
        end
      end

      # O helper que injeta o snippet do navegador, para quem quer os dois caminhos ou só o do
      # navegador. Ver o README: usar os dois ao mesmo tempo conta o pageview duas vezes.
      initializer "railstools_analytics.helper" do
        ActiveSupport.on_load(:action_view) do
          include Railstools::Analytics::ViewHelper
        end
      end
    end

    module ViewHelper
      # `<%= railstools_analytics_snippet %>` no layout.
      def railstools_analytics_snippet
        config = Analytics.config
        return "".html_safe unless config.enabled?

        tag.script(
          "", defer: true,
              src: "#{config.endpoint.to_s.chomp('/')}/js/analytics.js",
              data: { site: config.site, key: config.ingest_key, endpoint: config.endpoint }
        )
      end
    end
  end
end
