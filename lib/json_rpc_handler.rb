# frozen_string_literal: true

require 'json_rpc_handler/version'
require 'json'

module JsonRpcHandler
  class Version
    V1_0 = '1.0'
    V2_0 = '2.0'
  end

  class ErrorCode
    InvalidRequest = -32600
    MethodNotFound = -32601
    InvalidParams = -32602
    InternalError = -32603
    ParseError = -32700
  end

  module_function

  def handle(request, &method_finder)
    if request.is_a? Array
      return error_response id: :unknown_id, error: {
        code: ErrorCode::InvalidRequest,
        message: 'Invalid Request',
        data: 'Request is an empty array',
      } if request.empty?

      # Handle batch requests
      responses = request.map { |req| process_request req, &method_finder }.compact

      # A single item is hoisted out of the array
      return responses.first if responses.one?

      # An empty array yields nil
      responses if responses.any?
    elsif request.is_a? Hash
      # Handle single request
      process_request request, &method_finder
    else
      error_response id: :unknown_id, error: {
        code: ErrorCode::InvalidRequest,
        message: 'Invalid Request',
        data: 'Request must be an array or a hash',
      }
    end
  end

  def handle_json(request_json, &method_finder)
    begin
      request = JSON.parse request_json, symbolize_names: true
      response = handle request, &method_finder
    rescue JSON::ParserError
      response =error_response id: :unknown_id, error: {
        code: ErrorCode::ParseError,
        message: 'Parse error',
        data: 'Invalid JSON',
      }
    end

    response.to_json if response
  end

  def process_request(request, &method_finder)
    id = request[:id]

    error = case
      when !valid_version?(request[:jsonrpc]) then 'JSON-RPC version must be 2.0'
      when !valid_id?(request[:id]) then 'Request ID must be a string or an integer or null'
      when !valid_method_name?(request[:method]) then 'Method name must be a string and not start with "rpc."'
    end

    return error_response id: :unknown_id, error: {
      code: ErrorCode::InvalidRequest,
      message: 'Invalid Request',
      data: error,
    } if error

    method_name = request[:method]
    params = request[:params]

    unless valid_params? params
      return error_response id:, error: {
        code: ErrorCode::InvalidParams,
        message: 'Invalid params',
        data: 'Method parameters must be an array or an object or null',
      }
    end

    begin
      method = method_finder.call method_name

      if method.nil?
        return error_response id:, error: {
          code: ErrorCode::MethodNotFound,
          message: 'Method not found',
          data: method_name,
        }
      end

      result = method.call params

      success_response id:, result:
    rescue StandardError => e
      error_response id:, error: {
        code: ErrorCode::InternalError,
        message: 'Internal error',
        data: e.message,
      }
    end
  end

  def valid_version?(version)
    version == Version::V2_0
  end

  def valid_id?(id)
    id.is_a?(String) || id.is_a?(Integer) || id.nil?
  end

  def valid_method_name?(method)
    method.is_a?(String) && !method.start_with?('rpc.')
  end

  def valid_params?(params)
    params.nil? || params.is_a?(Array) || params.is_a?(Hash)
  end

  def success_response(id:, result:)
    {
      jsonrpc: Version::V2_0,
      id:,
      result:,
    } unless id.nil?
  end

  def error_response(id:, error:)
    {
      jsonrpc: Version::V2_0,
      id: valid_id?(id) ? id : nil,
      error: error.compact,
    } unless id.nil?
  end
end
