# Releasing json_rpc_handler

Publishing a GitHub release runs [the release workflow](.github/workflows/release.yml),
which builds and publishes [json_rpc_handler](https://rubygems.org/gems/json_rpc_handler)
through [RubyGems trusted publishing](https://guides.rubygems.org/trusted-publishing/).

## Release a version

1. Open a PR that updates [`lib/json_rpc_handler/version.rb`](lib/json_rpc_handler/version.rb)
   and [`CHANGELOG.md`](CHANGELOG.md). Leave `# Unreleased` empty and put the
   released entries under a new `# <version>` heading below it. Keep the older
   version sections unchanged.
2. After CI passes, merge that PR to `main`.
3. Publish a GitHub release with tag `v<version>` pointing at the merged commit.
   The tag must match the version in `version.rb`.
4. Check that the Release workflow passes and the new version appears on
   [RubyGems.org](https://rubygems.org/gems/json_rpc_handler).
