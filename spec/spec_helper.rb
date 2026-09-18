# frozen_string_literal: true

require "rack"
require "webmock/rspec"
require "railstools/analytics"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!

  # Cada exemplo começa com um agente limpo. Sem isto, a fila de um exemplo vaza para o
  # seguinte e o teste passa ou falha conforme a ordem do seed.
  config.before do
    Railstools::Analytics.instance_variable_set(:@config, nil)
    Railstools::Analytics.reset!
  end
end

def configurar(**opcoes)
  Railstools::Analytics.configure do |c|
    c.site = opcoes.fetch(:site, "exemplo.com.br")
    c.ingest_key = opcoes.fetch(:ingest_key, "chave-de-teste")
    c.endpoint = opcoes.fetch(:endpoint, "https://analytics.example")
    c.flush_interval = 3600 # a thread não dispara sozinha no meio de um exemplo
    opcoes.each { |k, v| c.public_send("#{k}=", v) if c.respond_to?("#{k}=") }
  end
end
