# Sigstore Check

Signs the gem the way [Gem Push](../gem-push/README.md) does and verifies the bundle against the caller's workflow identity, without pushing. Run it nightly, and on pull requests that change the push workflows, so a broken signer shows up before a release.

The caller sets up Ruby, builds exactly one `.gem` in the working directory and grants `id-token: write`. Forks do not get the OIDC token:

```yaml
on:
  schedule:
    - cron: '0 3 * * *'
  pull_request:
    paths:
      - '.github/workflows/sigstore_check.yml'
      - '.github/workflows/push*.yml'
  workflow_dispatch:

jobs:
  sign:
    if: >-
      github.event_name != 'pull_request' ||
      github.event.pull_request.head.repo.full_name == github.repository
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@<commit SHA> # vX
      - uses: ruby/setup-ruby@<commit SHA> # vX
      - name: Build the gem
        run: gem build *.gemspec
      - name: Sign and verify the gem
        uses: karafka/misc/.github/actions/sigstore-check@<commit SHA> # master
```
