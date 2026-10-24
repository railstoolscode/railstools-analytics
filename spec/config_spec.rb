# frozen_string_literal: true

RSpec.describe Railstools::Analytics::Config do
  def config_com(site:, chave:)
    described_class.new.tap do |config|
      config.site = site
      config.ingest_key = chave
    end
  end

  # Um agente que "liga" sem para onde mandar enche o log do app de quem instalou.
  it "fica desligado sem site ou sem chave" do
    expect(config_com(site: nil, chave: "k")).not_to be_enabled
    expect(config_com(site: "s", chave: nil)).not_to be_enabled
    expect(config_com(site: "s", chave: "k")).to be_enabled
  end

  it "ignora ativo, healthcheck e afins" do
    config = described_class.new

    %w[/assets/app.js /up /health /favicon.ico /robots.txt /imagem.png].each do |caminho|
      expect(config.ignore_path?(caminho)).to be(true), "#{caminho} não deveria virar pageview"
    end

    expect(config.ignore_path?("/precos")).to be(false)
  end

  it "ignora robô pelo user-agent" do
    config = described_class.new

    expect(config.ignore_user_agent?("Googlebot/2.1")).to be true
    expect(config.ignore_user_agent?("Mozilla/5.0 Chrome/120")).to be false
  end

  it "traduz o cabeçalho de IP para a chave do env do Rack" do
    config = described_class.new

    expect(config.ip_header_env_key).to be_nil

    config.ip_header = "CF-Connecting-IP"
    expect(config.ip_header_env_key).to eq("HTTP_CF_CONNECTING_IP")
  end
end
