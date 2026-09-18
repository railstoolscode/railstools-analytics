# frozen_string_literal: true

require_relative "lib/railstools/analytics/version"

Gem::Specification.new do |spec|
  spec.name = "railstools-analytics"
  spec.version = Railstools::Analytics::VERSION
  spec.authors = ["Diego Bentes"]
  spec.email = ["diegopbentes@gmail.com"]

  spec.summary = "Agente do Analytics: audiência de aplicações Ruby, sem cookie"
  spec.description = <<~TEXTO
    Mede audiência de uma aplicação Ruby (Rails, Sinatra, Rack) e envia para uma instalação do
    Analytics: pageviews, origens, páginas e eventos próprios.

    Sem cookie e sem identificador persistente — não há banner de consentimento a pedir. Ruby
    puro, sem extensão nativa e sem dependência fora da biblioteca padrão.
  TEXTO
  spec.homepage = "https://github.com/railstoolscode/railstools-analytics"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "bug_tracker_uri" => "#{spec.homepage}/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE"]
  spec.require_paths = ["lib"]
end
