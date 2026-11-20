# Gem Push

Signs the gem with Sigstore (`bin/sigstore`, sigstore-cli on json 2.x) and pushes it to RubyGems with `gem push --attestation`. When signing fails, nothing is pushed. `rubygems/release-gem` instead falls back to an unsigned push.

The action runs inside the caller's job, so the RubyGems trusted publisher and the Sigstore certificate identity stay the caller's push workflow.

The caller sets up Ruby, builds exactly one `.gem` in the working directory and grants `id-token: write`:

```yaml
jobs:
  push:
    runs-on: ubuntu-latest
    environment: deployment
    permissions:
      contents: write
      id-token: write
    steps:
      - uses: actions/checkout@<commit SHA> # vX
      - uses: ruby/setup-ruby@<commit SHA> # vX
      - name: Build the gem
        run: gem build *.gemspec
      - name: Sign and push the gem (with Sigstore attestation)
        uses: karafka/misc/.github/actions/gem-push@<commit SHA> # master
```
