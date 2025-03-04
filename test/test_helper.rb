# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  primary_coverage :branch
end

SimpleCov.minimum_coverage(branch: 100)

require 'json_rpc_handler'

require 'minitest/autorun'
