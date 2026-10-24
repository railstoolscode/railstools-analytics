# frozen_string_literal: true

module Railstools
  module Analytics
    # A configuração do agente.
    #
    # Tudo tem padrão vindo do ambiente, e o motivo é operacional: em contêiner, mexer em
    # variável é um `kamal env push`, e mexer em initializer é um deploy.
    class Config
      DEFAULT_ENDPOINT = "https://analytics.railstools.com.br"

      attr_accessor :site, :ingest_key, :endpoint, :enabled,
                    :flush_interval, :max_batch, :open_timeout, :read_timeout,
                    :ignore_paths, :ignore_user_agents, :logger, :ip_header

      def initialize
        @site = ENV.fetch("RAILSTOOLS_ANALYTICS_SITE", nil)
        @ingest_key = ENV.fetch("RAILSTOOLS_ANALYTICS_KEY", nil)
        @endpoint = ENV.fetch("RAILSTOOLS_ANALYTICS_ENDPOINT", DEFAULT_ENDPOINT)

        # Ligado só quando há chave E site. Um agente que "liga" sem para onde mandar é um
        # agente que enche o log de erro em toda requisição do app de quem nos instalou.
        @enabled = nil

        @flush_interval = Float(ENV.fetch("RAILSTOOLS_ANALYTICS_FLUSH_INTERVAL", 5))
        @max_batch = Integer(ENV.fetch("RAILSTOOLS_ANALYTICS_MAX_BATCH", 200))
        @open_timeout = 2
        @read_timeout = 5

        # O que nunca é pageview. Ativo, healthcheck e a própria ingestão entram aqui porque
        # medi-los enche o painel com linhas que ninguém pediu e que escondem as páginas reais.
        @ignore_paths = [
          %r{\A/assets/}, %r{\A/packs/}, %r{\A/vite/}, %r{\A/rails/active_storage/},
          %r{\A/cable\z}, %r{\A/up\z}, %r{\A/health}, %r{\A/favicon}, %r{\A/robots\.txt\z},
          %r{\A/sitemap}, /\.(?:js|css|map|png|jpe?g|gif|svg|ico|woff2?|ttf|webp|avif)\z/
        ]

        @ignore_user_agents = /bot|crawler|spider|scraper|curl|wget|monitor|uptime|healthcheck|kube-probe/i
        @logger = nil

        # O cabeçalho com o IP de quem visita, quando um proxy da frente o escreve
        # ("CF-Connecting-IP" na Cloudflare). Desligado por padrão: qualquer um pode mandar esse
        # cabeçalho, e só vale ligar quando o app SÓ é alcançado por esse proxy (ver
        # `Middleware::Tracking#ip_de`).
        @ip_header = ENV.fetch("RAILSTOOLS_ANALYTICS_IP_HEADER", nil)
      end

      def enabled?
        return @enabled unless @enabled.nil?

        site.to_s.strip != "" && ingest_key.to_s.strip != ""
      end

      def events_url = "#{endpoint.to_s.chomp('/')}/api/v1/events"

      def ignore_path?(path) = ignore_paths.any? { |padrao| padrao.match?(path.to_s) }

      def ignore_user_agent?(agent) = ignore_user_agents.match?(agent.to_s)

      # "CF-Connecting-IP" -> "HTTP_CF_CONNECTING_IP", a chave do env do Rack.
      def ip_header_env_key
        nome = ip_header.to_s.strip
        "HTTP_#{nome.upcase.tr('-', '_')}" unless nome.empty?
      end
    end
  end
end
