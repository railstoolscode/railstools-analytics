# frozen_string_literal: true

RSpec.describe Railstools::Analytics::Dispatcher do
  before { configurar }

  def evento = { name: "pageview", url: "https://exemplo.com.br/" }

  it "manda o lote acumulado" do
    requisicao = stub_request(:post, "https://analytics.example/api/v1/events").to_return(status: 202)

    3.times { Railstools::Analytics.dispatcher.push(evento) }
    Railstools::Analytics.dispatcher.flush

    expect(requisicao).to have_been_made.once
  end

  it "manda a chave no cabeçalho, não no corpo" do
    requisicao = stub_request(:post, "https://analytics.example/api/v1/events")
                 .with(headers: { "X-Ingest-Key" => "chave-de-teste" })
                 .to_return(status: 202)

    Railstools::Analytics.dispatcher.push(evento)
    Railstools::Analytics.dispatcher.flush

    expect(requisicao).to have_been_made
  end

  # Um agente de medição derrubando por falta de memória o app que ele mede é inaceitável.
  it "descarta em vez de crescer sem limite quando o servidor some" do
    config = Railstools::Analytics.config
    teto = config.max_batch * 10

    (teto + 50).times { Railstools::Analytics.dispatcher.push(evento) }

    expect(Railstools::Analytics.dispatcher.size).to eq(teto)
  end

  # Exceção na thread de envio mata a thread, e o agente fica mudo para sempre.
  it "não deixa falha de rede subir" do
    stub_request(:post, "https://analytics.example/api/v1/events").to_timeout

    Railstools::Analytics.dispatcher.push(evento)

    expect { Railstools::Analytics.dispatcher.flush }.not_to raise_error
  end

  it "não chama a rede com a fila vazia" do
    stub_request(:post, "https://analytics.example/api/v1/events")

    Railstools::Analytics.dispatcher.flush

    expect(a_request(:post, "https://analytics.example/api/v1/events")).not_to have_been_made
  end
end
