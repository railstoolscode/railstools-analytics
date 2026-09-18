# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Railstools
  module Analytics
    # O envio HTTP do lote.
    #
    # **Nunca deixa a exceção subir.** Quem chama é a thread de despacho, e uma exceção lá mata
    # a thread — o agente fica mudo para sempre, sem que ninguém perceba. É a pior falha
    # possível num agente: o app de quem nos instalou continua funcionando, e o painel
    # simplesmente para de receber, o que se lê como "ninguém visitou o site".
    class Transmitter
      RETRIABLE = [
        Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT,
        Net::OpenTimeout, Net::ReadTimeout, SocketError, IOError, EOFError
      ].freeze

      def initialize(config)
        @config = config
      end

      def deliver(events, retries: 1)
        return true if events.empty?

        uri = URI.parse(@config.events_url)
        resposta = Net::HTTP.start(
          uri.hostname, uri.port,
          use_ssl: uri.scheme == "https",
          open_timeout: @config.open_timeout, read_timeout: @config.read_timeout
        ) { |http| http.request(requisicao(uri, events)) }

        return true if resposta.is_a?(Net::HTTPSuccess)

        Analytics.warn("o Analytics respondeu #{resposta.code} — #{events.size} evento(s) descartado(s)")
        false
      rescue *RETRIABLE => e
        return deliver(events, retries: retries - 1) if retries.positive?

        Analytics.warn("não consegui enviar para #{@config.endpoint}: #{e.class} #{e.message}")
        false
      rescue StandardError => e
        Analytics.warn("erro inesperado ao enviar: #{e.class} #{e.message}")
        false
      end

      private

      def requisicao(uri, events)
        Net::HTTP::Post.new(uri).tap do |req|
          req["Content-Type"] = "application/json"
          req["X-Ingest-Key"] = @config.ingest_key
          req["User-Agent"] = "railstools-analytics/#{VERSION}"
          req.body = JSON.generate(events: events)
        end
      end
    end
  end
end
