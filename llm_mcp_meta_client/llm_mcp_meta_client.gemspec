require_relative "lib/llm_mcp_meta_client/version"

Gem::Specification.new do |spec|
  spec.name        = "llm_mcp_meta_client"
  spec.version     = LlmMcpMetaClient::VERSION
  spec.authors     = [ "dhq_boiler" ]
  spec.email       = [ "dhq_boiler@live.jp" ]
  spec.homepage    = "TODO"
  spec.summary     = "TODO: Summary of LlmMcpMetaClient."
  spec.description = "TODO: Description of LlmMcpMetaClient."

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.1"
end
