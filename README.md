# json_rpc_handler

A lightweight, fully spec-compliant [JSON-RPC 2.0][1] handler.

It only deals with the parsing and handling of JSON-RPC requests, producing
appropriate JSON-RPC responses.

It does not deal with the transport layer (e.g. HTTP, WebSockets, etc.)

[1] https://www.jsonrpc.org/specification

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json_rpc_handler'
```

And then execute:

```sh
bundle
```

Or install it yourself as:

```sh
gem install json_rpc_handler
```

## Usage

If you already have a request object parsed from JSON, you can use the `handle`
method. Pass a block to the `handle` call to look up methods by name:

```rb
require 'json_rpc_handler'

request = {
  jsonrpc: '2.0',
  id: 1,
  method: 'add',
  params: {a: 1, b: 2},
}

result = JsonRpcHandler.handle(request) do |method_name|
  case method_name
  when 'add'
    ->(params) { params[:a] + params[:b] }
  end
end

puts result.to_json
# {"jsonrpc":"2.0","id":1,"result":3}
```

Returning a `nil` from the method lookup block will result in a method not found
error.

If the request JSON is not already parsed, you can use the `handle_json` method:

```rb
request_json = '{"jsonrpc": "2.0","id":1,"method":"add","params":{"a":1,"b":2}}'

result_json = JsonRpcHandler.handle_json(request_json) do |method_name|
  case method_name
  when 'add'
    ->(params) { params[:a] + params[:b] }
  end
end

puts result_json
# {"jsonrpc":"2.0","id":1,"result":3}
```

A `nil` from `handle` or `handle_json` means "no content" - either the
method returned `nil`, or all method calls of a batch request returned `nil`. It
is up to the integration to apply the appropriate transport-layer semantics
(e.g. returning a 204 No Content).

## Development

After checking out the repo:

1. Run `bundle` to install dependencies.
2. Run `rake test` to run the tests, including code coverage.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/Shopify/json_rpc_handler. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to adhere
to the [Contributor Covenant][2] code of conduct. Read more about contributing
[here][3].

[2]: https://contributor-covenant.org
[3]: https://github.com/Shopify/json_rpc_handler/blob/main/CONTRIBUTING.md

## License

The gem is available as open source under the terms of the [MIT License][4].

[4]: https://opensource.org/licenses/MIT

## Code of Conduct

Everyone interacting in this repository is expected to follow the
[Code of Conduct][5].

[5]: https://github.com/Shopify/json_rpc_handler/blob/main/CODE_OF_CONDUCT.md
