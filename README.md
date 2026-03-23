# yolo-ng

Anonymous text board module for Logos Core.

## Features

- Create, delete, and like posts on an anonymous text board
- Posts are persisted via Logos Core KV storage (when available)
- **Zone sequencer inscription**: every new post is published on-chain via `logos-zone-sequencer-module` using Logos Core inter-module IPC (QtRO)

## Zone Sequencer Integration

When a post is created, yolo-ng configures and calls `publish` on `liblogos_zone_sequencer_module` with:
- **Node URL**: configurable blockchain node endpoint
- **Signing key**: hardcoded development key
- **Checkpoint path**: `/tmp/yolo_ng_sequencer.checkpoint`

The returned inscription ID is stored on the post and included in the posts API output.

## Build

```sh
# Full .lgx package (variants/ structure)
nix build .#lgx

# Headless plugin only
nix build .#headless-plugin

# UI plugin only
nix build .#ui-plugin
```

## LGX Package Structure

The `.lgx` output uses a variants directory layout:

```
manifest.json               # root: name, version, type, variants list
variants/
  linux-x86_64/
    manifest.json            # full module manifest
    yolo_ng_plugin.so        # headless plugin
    libyolo_ng_ui.so         # UI plugin
    qml/                     # QML resources
    metadata.json
    ui_metadata.json
```

## Headless Testing

Test zone sequencer inscription without a GUI:

```sh
logoscore -c "yolo_ng.testInscription()"
```

This calls `createPost` with author `test-agent` and a timestamped message, then returns the inscription ID.

## Architecture

- `YoloNgPlugin` — headless Logos Core plugin (PluginInterface), forwards to YoloNgBoard
- `YoloNgBoard` — board logic, post management, zone sequencer inscription
- `YoloNgUIComponent` — IComponent UI factory for logos-app
