# Karafka misc

Shared assets (charts, logos, screenshots) and tools for the Karafka ecosystem.

## CHANGELOG checker

`bin/verify_changelog` checks the entries of a gem's `CHANGELOG.md`. It is plain Ruby (stdlib only, Ruby 3.3+).

It checks only the `## ... (Unreleased)` (or `## Unreleased`) block, or the topmost version block when there is none. Released versions below are never checked. Each top-level `- ` line of that block is an entry; indented lines are not. Every entry must start with one of these tags, in this order:

`[Breaking]` `[EOL]` `[Feature]` `[Enhancement]` `[Change]` `[Refactor]` `[Maintenance]` `[Patch]` `[Fix]`

- Entries with the same tag stay together, and a tag must not appear after a later one.
- A bold tag (`**[Feature]**`) is the same as the plain one (`[Feature]`).
- A synonym fails with its main tag as a hint: `[Improvement]` -> `[Enhancement]`, `[Refactoring]` -> `[Refactor]`, `[Breaking change]` -> `[Breaking]`, `[Deprecation]`/`[Deprecated]` -> `[Change]`.
- `[Testing]` and `[Specs]` fail: test-only changes get no entry.
- An unknown tag or an untagged entry fails.
- `[Patch]` (a patch to librdkafka's source) is allowed only in `rdkafka-ruby` and `karafka-rdkafka`.

```bash
bin/verify_changelog [--repo NAME] [PATH]
```

`PATH` defaults to `CHANGELOG.md`. The repo name comes from `--repo` or `GITHUB_REPOSITORY`. Each finding is printed as `PATH:LINE: problem`; the exit code is 1 when there is any finding and 0 when the block is clean.

Run the tests with `ruby test/verify_changelog_test.rb`.

### Use in a repo's CI

The reusable workflow `.github/workflows/changelog-lint.yml` checks out the calling repo and this one and runs the checker on the caller's `CHANGELOG.md`. Call it from a job pinned to a commit SHA of this repo, and add the job to the `needs` of the repo's `ci-success` job:

```yaml
jobs:
  changelog:
    uses: karafka/misc/.github/workflows/changelog-lint.yml@<commit SHA> # master
```
