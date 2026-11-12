# Example Changelog

## 1.1.0 (Unreleased)
- **[Breaking]** Remove the deprecated `#old` method.
- **[EOL]** Drop Ruby 3.2 support; require Ruby 3.3+.
- **[Feature]** Add `#new`.
- [Feature] Add `#other`.
  Continuation line of the entry above.
  - A sub-list line that is not an entry.
- [Enhancement] Make `#new` faster.
- [Change] Raise `ArgumentError` for a negative timeout.
- [Refactor] Rework the internal buffer.
- [Maintenance] Require karafka-core `>= 2.6.3`.
- [Fix] [Pro] Keep the pause state after a rebalance.
- [Fix] Stop `#close` from hanging.

## 1.0.0 (2026-01-01)
- [Fix] An entry in a released block.
