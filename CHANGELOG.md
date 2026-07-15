# Changelog

## Unreleased

### Fixed

- Make boolean input normalization compatible with the Bash version shipped on GitHub-hosted macOS runners.

### Added

- CI smoke tests on Ubuntu and macOS, plus ShellCheck validation.

## v1.0.0 - 2026-05-21

Initial public release.

### Added

- Bash/curl composite GitHub Action.
- Telegram Bot API `sendMessage` integration.
- Release notification generated from `release.published` context.
- Custom message support.
- Telegram forum topic support through `message-thread-id`.
- Silent notifications through `disable-notification`.
- Link preview disabling through `link_preview_options`.
- Protected content option.
- Message/body truncation safeguards.
- Local smoke tests using fake `curl`.
- Telegram setup, troubleshooting, and usage examples.
