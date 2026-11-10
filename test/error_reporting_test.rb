# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

describe 'JsonRpcHandler error reporting' do
  def rpc_request(id: 1)
    request = { jsonrpc: '2.0', method: 'run' }
    request[:id] = id unless id.nil?
    request
  end

  def internal_error(id: 1)
    { jsonrpc: '2.0', id: id, error: { code: -32603, message: 'Internal error' } }
  end

  def dispatch(entrypoint, request, on_error: nil, &method_finder)
    if entrypoint == :handle_json
      response = JsonRpcHandler.handle_json(request.to_json, on_error: on_error, &method_finder)
      JSON.parse(response, symbolize_names: true) if response
    else
      JsonRpcHandler.handle(request, on_error: on_error, &method_finder)
    end
  end

  [:handle, :handle_json].each do |entrypoint|
    describe "##{entrypoint}" do
      it 'reports a method lookup exception with its request context' do
        exception = StandardError.new('Lookup details')
        reports = []

        response = dispatch(entrypoint, rpc_request, on_error: ->(error, context) { reports << [error, context] }) do
          raise exception
        end

        assert_equal internal_error, response
        assert_equal 1, reports.length
        assert_same exception, reports.first[0]
        assert_equal({ id: 1, method: 'run' }, reports.first[1])
      end

      it 'reports a method exception with its request context' do
        exception = StandardError.new('Method details').freeze
        reports = []

        response = dispatch(entrypoint, rpc_request(id: 'request-1'), on_error: ->(error, context) { reports << [error, context] }) do
          ->(_params) { raise exception }
        end

        assert_equal internal_error(id: 'request-1'), response
        assert_equal 1, reports.length
        assert_same exception, reports.first[0]
        assert_equal({ id: 'request-1', method: 'run' }, reports.first[1])
      end

      it 'ignores an exception from the hook without calling it again' do
        calls = 0
        on_error = lambda do |_exception, _context|
          calls += 1
          raise StandardError, 'Reporter details'
        end

        response = dispatch(entrypoint, rpc_request, on_error: on_error) do
          ->(_params) { raise StandardError, 'Method details' }
        end

        assert_equal internal_error, response
        assert_equal 1, calls
      end

      it 'reports a failing notification with a nil request id' do
        exception = StandardError.new('Method details')
        reports = []

        response = dispatch(entrypoint, rpc_request(id: nil), on_error: ->(error, context) { reports << [error, context] }) do
          ->(_params) { raise exception }
        end

        assert_nil response
        assert_equal [[exception, { id: nil, method: 'run' }]], reports
      end

      it 'reports each internal error in a batch and keeps explicit errors and successes' do
        exception = StandardError.new('Method details')
        reports = []
        requests = [
          { jsonrpc: '2.0', id: 1, method: 'fail' },
          { jsonrpc: '2.0', id: 2, method: 'expected' },
          { jsonrpc: '2.0', id: 3, method: 'ping' },
          { jsonrpc: '2.0', method: 'fail' },
        ]

        response = dispatch(entrypoint, requests, on_error: ->(error, context) { reports << [error, context] }) do |method_name|
          case method_name
          when 'fail' then ->(_params) { raise exception }
          when 'expected' then ->(_params) { raise JsonRpcHandler::Error.new(code: -32001, message: 'Try later', data: false) }
          when 'ping' then ->(_params) { 'pong' }
          end
        end

        assert_equal [
          internal_error,
          { jsonrpc: '2.0', id: 2, error: { code: -32001, message: 'Try later', data: false } },
          { jsonrpc: '2.0', id: 3, result: 'pong' },
        ], response
        assert_equal [
          [exception, { id: 1, method: 'fail' }],
          [exception, { id: nil, method: 'fail' }],
        ], reports
      end

      it 'does not report successful calls or other response errors' do
        reports = []
        on_error = ->(error, context) { reports << [error, context] }

        response = dispatch(entrypoint, rpc_request, on_error: on_error) { ->(_params) { 'done' } }
        assert_equal({ jsonrpc: '2.0', id: 1, result: 'done' }, response)

        response = dispatch(entrypoint, rpc_request, on_error: on_error) { nil }
        assert_equal({ jsonrpc: '2.0', id: 1, error: { code: -32601, message: 'Method not found', data: 'run' } }, response)

        response = dispatch(entrypoint, { jsonrpc: '2.0', id: 1 }, on_error: on_error) { flunk 'Lookup should not run' }
        assert_equal({ jsonrpc: '2.0', id: nil, error: { code: -32600, message: 'Invalid Request', data: 'Method name must be a string and not start with "rpc."' } }, response)
        assert_empty reports
      end

      it 'returns explicit error fields without calling the hook' do
        [nil, false, 0, '', [], {}, { reason: 'retry' }].each do |data|
          exception = JsonRpcHandler::Error.new(code: -32001, message: 'Try later', data: data)
          reports = []
          expected_error = { code: -32001, message: 'Try later' }
          expected_error[:data] = data unless data.nil?

          response = dispatch(entrypoint, rpc_request, on_error: ->(error, context) { reports << [error, context] }) do
            ->(_params) { raise exception }
          end

          assert_kind_of StandardError, exception
          assert_equal({ jsonrpc: '2.0', id: 1, error: expected_error }, response)
          assert_empty reports
        end
      end

      it 'returns an explicit lookup error without a message fallback for omitted data' do
        exception = JsonRpcHandler::Error.new(code: -32001, message: 'Try later')
        reports = []

        response = dispatch(entrypoint, rpc_request, on_error: ->(error, context) { reports << [error, context] }) do
          raise exception
        end

        assert_equal({ jsonrpc: '2.0', id: 1, error: { code: -32001, message: 'Try later' } }, response)
        assert_empty reports
      end

      it 'does not respond to or report an explicit notification error' do
        reports = []
        response = dispatch(entrypoint, rpc_request(id: nil), on_error: ->(error, context) { reports << [error, context] }) do
          ->(_params) { raise JsonRpcHandler::Error.new(code: -32001, message: 'Try later') }
        end

        assert_nil response
        assert_empty reports
      end
    end
  end

  it 'calls the hook before building the internal error response' do
    events = []
    response = nil
    build_response = JsonRpcHandler.method(:error_response)
    on_error = ->(_exception, _context) { events << :hook }
    observe_response = lambda do |**arguments|
      events << :response
      build_response.call(**arguments)
    end

    JsonRpcHandler.stub(:error_response, observe_response) do
      response = JsonRpcHandler.handle(rpc_request, on_error: on_error) do
        ->(_params) { raise StandardError, 'Method details' }
      end
    end

    assert_equal [:hook, :response], events
    assert_equal internal_error, response
  end

  it 'does not call the hook for a JSON parse error' do
    reports = []
    response = JsonRpcHandler.handle_json('{', on_error: ->(error, context) { reports << [error, context] }) { nil }

    assert_equal({ jsonrpc: '2.0', id: nil, error: { code: -32700, message: 'Parse error', data: 'Invalid JSON' } }, JSON.parse(response, symbolize_names: true))
    assert_empty reports
  end
end
