# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'json_rpc_handler/version'

Gem::Specification.new do |spec|
  spec.name          = 'json_rpc_handler'
  spec.version       = JsonRpcHandler::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Ates Goral']
  spec.email         = ['ates.goral@shopify.com']

  spec.summary       = 'A spec-compliant JSON-RPC 2.0 handler'
  spec.homepage      = 'https://github.com/Shopify/json_rpc_handler'
  spec.license       = 'MIT'

  spec.required_ruby_version     = '>= 2.6.0'
  spec.required_rubygems_version = '>= 1.3.7'

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/Shopify/json_rpc_handler/issues',
    'changelog_uri' => 'https://github.com/Shopify/json_rpc_handler/blob/main/CHANGELOG.md',
    'source_code_uri' => 'https://github.com/Shopify/json_rpc_handler',
    'allowed_push_host' => 'https://rubygems.org',
    'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir.glob('{lib}/**/*') + ['LICENSE.md', 'README.md']

  spec.extra_rdoc_files = ['README.md']

  spec.require_paths = ['lib']
end
