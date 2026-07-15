# Telegram Release Notify via Curl

[![CI](https://github.com/nekrasovp/telegram-release-notify/actions/workflows/ci.yml/badge.svg)](https://github.com/nekrasovp/telegram-release-notify/actions/workflows/ci.yml)

A tiny GitHub Action that sends release notifications to Telegram with **Bash + curl**.

No server. No Docker. No Node.js. No package manager. No deployment.

The action and smoke suite run on the Bash versions shipped by current GitHub-hosted Ubuntu and macOS runners.

## What it does

When a GitHub Release is published, this action sends a Telegram message with:

- release title
- repository name
- tag
- release author
- release URL
- optional release notes/body

The action uses Telegram Bot API `sendMessage` through `curl`.

## Quick start

Create a Telegram bot with BotFather, get the bot token, then add these repository secrets in the project that should send release notifications:

```text
TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID
```

See [`docs/setup-telegram.md`](docs/setup-telegram.md) for bot creation and chat id discovery.

Create `.github/workflows/telegram-release.yml` in the other project that should use this action:

```yaml
name: Telegram release notification

on:
  release:
    types: [published]

permissions:
  contents: read

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: nekrasovp/telegram-release-notify@v1
        with:
          bot-token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
```

## Use with Telegram topics

```yaml
- uses: nekrasovp/telegram-release-notify@v1
  with:
    bot-token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
    message-thread-id: ${{ vars.TELEGRAM_THREAD_ID }}
```

## Use a custom message

```yaml
- uses: nekrasovp/telegram-release-notify@v1
  with:
    bot-token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
    text: |
      🚀 Release ${{ github.ref_name }} is ready

      Repository: ${{ github.repository }}
      https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}
```

By default messages are sent as plain text. If you set `parse-mode` to `HTML` or `MarkdownV2`, escape any custom text and release body according to Telegram's formatting rules, especially when the content comes from GitHub release notes.

## Use in the same workflow that creates the release

If a release is created by another workflow with the default `GITHUB_TOKEN`, a separate workflow listening on `release.published` may not run. In that case, send Telegram notification in the same workflow after creating the release:

```yaml
name: Release

on:
  push:
    tags:
      - "v*.*.*"

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh release create "${GITHUB_REF_NAME}" --title "${GITHUB_REF_NAME}" --generate-notes

      - name: Notify Telegram
        uses: nekrasovp/telegram-release-notify@v1
        with:
          bot-token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
          chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
          release-title: ${{ github.ref_name }}
          release-tag: ${{ github.ref_name }}
          release-url: https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}
          include-release-body: false
```

## Inputs

| Input | Required | Default | Description |
|---|---:|---|---|
| `bot-token` | yes | | Telegram bot token from BotFather. Use a GitHub secret. |
| `chat-id` | yes | | Telegram chat/group/channel id or channel username like `@my_channel`. |
| `message-thread-id` | no | | Telegram forum topic/thread id. |
| `text` | no | | Custom message. When set, automatic release message generation is skipped. |
| `release-title` | no | | Release title override. |
| `release-tag` | no | | Release tag override. |
| `release-url` | no | | Release URL override. |
| `release-body` | no | | Release notes/body override. |
| `include-release-body` | no | `true` | Append release notes/body to the generated message. |
| `max-body-chars` | no | `1200` | Max release body characters to include. Set `0` to omit body content. |
| `max-message-chars` | no | `3900` | Max Telegram text length before truncation. Telegram limit is 4096. |
| `parse-mode` | no | | Optional Telegram parse mode, for example `HTML` or `MarkdownV2`. Empty means safe plain text. |
| `disable-notification` | no | `false` | Send silently. |
| `disable-link-preview` | no | `false` | Disable link preview via `link_preview_options.is_disabled`. |
| `protect-content` | no | `false` | Ask Telegram to protect the message from forwarding/saving where supported. |

## Outputs

| Output | Description |
|---|---|
| `sent` | `true` when Telegram accepted the message. |
| `http-status` | HTTP status returned by Telegram Bot API. |

## Why Bash + curl?

The job is a single HTTP call to Telegram. A composite action keeps the user experience simple:

```yaml
- uses: nekrasovp/telegram-release-notify@v1
  with:
    bot-token: ${{ secrets.TELEGRAM_BOT_TOKEN }}
    chat-id: ${{ secrets.TELEGRAM_CHAT_ID }}
```

There is no long-running bot process, webhook server, container, Node bundle, Rust binary, or Python dependency.

## Local verification

```bash
make test
```

The tests use a fake `curl` binary and do not call Telegram.

## Security

- Never commit `TELEGRAM_BOT_TOKEN`.
- Store the token as a GitHub Actions secret.
- The script masks the token in GitHub Actions logs.
- Release body and custom text are sent as form data to Telegram; they are not evaluated as shell code.

## License

MIT
