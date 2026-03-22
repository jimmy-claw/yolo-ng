# yolo-ng

Anonymous text board module for Logos Core.

## Features

- Create, delete, and like posts on an anonymous text board
- Posts are persisted via Logos Core KV storage (when available)
- **Blockchain inscription**: every new post is inscribed on-chain via `blockchain_module.zone_inscribe()` using Logos Core inter-module IPC (QtRO)

## Blockchain Integration

When a post is created, yolo-ng calls `zone_inscribe` on `liblogos_blockchain_module` with:
- **Channel ID**: SHA-256 of `"yolo-ng-board"`
- **Data**: the post content
- **Signing key**: hardcoded development key

The returned inscription ID is stored on the post and included in the posts API output.

## Build

```sh
# Full .lgx package
nix build .#lgx

# Headless plugin only
nix build .#headless-plugin

# UI plugin only
nix build .#ui-plugin
```

## Architecture

- `YoloNgPlugin` — headless Logos Core plugin (PluginInterface), forwards to YoloNgBoard
- `YoloNgBoard` — board logic, post management, blockchain inscription
- `YoloNgUIComponent` — IComponent UI factory for logos-app
