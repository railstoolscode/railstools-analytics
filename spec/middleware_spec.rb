# frozen_string_literal: true

RSpec.describe Railstools::Analytics::Middleware::Tracking do
  let(:html) { [200, { "content-type" => "text/html; charset=utf-8" }, ["oi"]] }

  # `Rack::MOCK_ENV` saiu no Rack 3; `env_for` é o caminho atual.
  def env_de(caminho, metodo, extras)
    Rack::MockRequest.env_for(
      "https://exemplo.com.br#{caminho}",
      method: metodo, "HTTP_USER_AGENT" => "Mozilla/5.0 Chrome/120"
    ).merge(extras)
  end

  def rodar(app_resposta: html, caminho: "/precos", metodo: "GET", env: {})
    described_class.new(->(_) { app_resposta }).call(env_de(caminho, metodo, env))
  end

  before { configurar }

  it "conta o GET que devolve HTML" do
    rodar

    expect(Railstools::Analytics.dispatcher.size).to eq(1)
  end

  it "não conta POST, redirecionamento nem resposta que não é HTML" do
    rodar(metodo: "POST")
    rodar(app_resposta: [302, { "content-type" => "text/html" }, []])
    rodar(app_resposta: [200, { "content-type" => "application/json" }, ["{}"]])

    expect(Railstools::Analytics.dispatcher.size).to eq(0)
  end

  it "não conta ativo nem healthcheck" do
    rodar(caminho: "/assets/app.js")
    rodar(caminho: "/up")

    expect(Railstools::Analytics.dispatcher.size).to eq(0)
  end

  it "não conta robô" do
    rodar(env: { "HTTP_USER_AGENT" => "Googlebot/2.1" })

    expect(Railstools::Analytics.dispatcher.size).to eq(0)
  end

  # A regra que não pode ser quebrada: um agente de medição que estoura numa requisição do
  # cliente é infinitamente pior que um agente que perde um pageview.
  it "não derruba o app quando a medição falha" do
    allow(Railstools::Analytics).to receive(:track_pageview).and_raise("caos")

    expect { rodar }.not_to raise_error
  end

  # E a exceção do APP continua subindo: engoli-la esconderia o erro de quem nos instalou.
  it "deixa a exceção do app subir" do
    app = ->(_) { raise ArgumentError, "erro do app" }
    middleware = described_class.new(app)

    expect { middleware.call(env_de("/", "GET", {})) }.to raise_error(ArgumentError, "erro do app")
  end

  it "fica quieto quando o agente está desligado" do
    Railstools::Analytics.configure { _1.ingest_key = nil }

    rodar

    expect(Railstools::Analytics.dispatcher.size).to eq(0)
  end

  it "não conta prefetch: o do navegador, o do Turbo e os antigos" do
    rodar(env: { "HTTP_SEC_PURPOSE" => "prefetch" })
    rodar(env: { "HTTP_SEC_PURPOSE" => "prefetch;prerender" })
    rodar(env: { "HTTP_X_SEC_PURPOSE" => "prefetch" })
    rodar(env: { "HTTP_PURPOSE" => "prefetch" })
    rodar(env: { "HTTP_X_MOZ" => "prefetch" })

    expect(Railstools::Analytics.dispatcher.size).to eq(0)
  end

  describe "o IP de quem visita" do
    # Só o que o middleware entregaria; nada entra na fila nem sai para a rede.
    before { allow(Railstools::Analytics).to receive(:track_pageview) }

    def ip_medido
      ip = nil
      expect(Railstools::Analytics).to have_received(:track_pageview) { |**dados| ip = dados[:ip] }
      ip
    end

    # Atrás de um proxy público, o Rack devolve o IP do proxy: todo visitante viraria o mesmo.
    let(:atras_da_cloudflare) do
      { "REMOTE_ADDR" => "172.18.0.5", "HTTP_X_FORWARDED_FOR" => "200.150.10.20, 104.16.0.10",
        "HTTP_CF_CONNECTING_IP" => "200.150.10.20" }
    end

    it "usa o IP que o Rails resolveu com os proxies confiáveis do app" do
      rails = Struct.new(:ip) { def to_s = ip }.new("200.150.10.20")

      rodar(env: atras_da_cloudflare.merge("action_dispatch.remote_ip" => rails))

      expect(ip_medido).to eq("200.150.10.20")
    end

    it "cai no do Rack quando o Rails não resolveu ou levantou erro" do
      explode = Object.new.tap { |o| def o.to_s = raise("IpSpoofAttackError") }

      rodar(env: { "REMOTE_ADDR" => "203.0.113.7", "action_dispatch.remote_ip" => explode })

      expect(ip_medido).to eq("203.0.113.7")
    end

    it "usa o cabeçalho configurado antes de tudo" do
      configurar(ip_header: "CF-Connecting-IP")

      rodar(env: atras_da_cloudflare)

      expect(ip_medido).to eq("200.150.10.20")
    end

    it "não confia no cabeçalho que ninguém configurou" do
      rodar(env: atras_da_cloudflare)

      expect(ip_medido).to eq("104.16.0.10")
    end
  end
end
