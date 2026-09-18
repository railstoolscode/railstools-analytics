# frozen_string_literal: true

require "json"

require_relative "analytics/version"
require_relative "analytics/config"
require_relative "analytics/transmitter"
require_relative "analytics/dispatcher"
require_relative "analytics/middleware/tracking"

module Railstools
  # Agente do Analytics: manda pageview e evento próprio de uma aplicação Ruby.
  #
  # Ruby puro, sem extensão nativa e sem dependência fora da biblioteca padrão — instalar não
  # pode ser um problema de infraestrutura para quem só quer medir audiência.
  #
  # SEM COOKIE, E ISSO É DE PROJETO
  # -------------------------------
  # O agente não lê nem escreve nada no navegador. Quem identifica o visitante é o servidor, a
  # partir de IP, user-agent e domínio, com um sal que gira todo dia e é apagado. Não há
  # identificador persistente em lugar nenhum — por isso não há banner de consentimento a pedir.
  module Analytics
    class << self
      def config = @config ||= Config.new

      def configure
        yield(config) if block_given?
        reset!
        config
      end

      def enabled? = config.enabled?

      def dispatcher = @dispatcher ||= Dispatcher.new(config)

      def reset!
        @dispatcher = nil
      end

      # Um pageview. É o que o middleware chama.
      def track_pageview(url:, user_agent:, ip:, referrer: nil)
        track("pageview", url: url, user_agent: user_agent, ip: ip, referrer: referrer)
      end

      # Um evento próprio: `Railstools::Analytics.track("Assinatura", url: …, plano: "growth")`.
      #
      # Serve para o que o navegador não sabe — assinatura confirmada pelo webhook do
      # pagamento, job que terminou, conversão que acontece do lado do servidor.
      def track(name, url:, user_agent: nil, ip: nil, referrer: nil, props: {})
        return false unless enabled?

        dispatcher.push(
          name: name,
          url: url,
          referrer: referrer,
          user_agent: user_agent,
          ip: ip,
          props: props,
          occurred_at: Time.now.utc.iso8601
        )

        true
      rescue StandardError => e
        # Medir NUNCA derruba quem mede.
        warn_internal("não consegui registrar #{name.inspect}: #{e.class} #{e.message}")
        false
      end

      def flush = dispatcher.flush_all

      def warn(mensagem) = warn_internal(mensagem)

      private

      def warn_internal(mensagem)
        texto = "[railstools-analytics] #{mensagem}"

        if config.logger
          config.logger.warn(texto)
        else
          Kernel.warn(texto)
        end
      end
    end
  end
end

require_relative "analytics/integrations/railtie" if defined?(Rails::Railtie)

# O último lote não pode morrer com o processo: sem isto, todo deploy perde os eventos do
# intervalo que ainda não tinha sido enviado.
at_exit { Railstools::Analytics.flush if Railstools::Analytics.enabled? }
