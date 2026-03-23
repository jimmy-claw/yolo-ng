# yolo-ng

A decentralized text board running as a Logos Core module. Users create named boards with a secret, post text, and every post is permanently inscribed on the Logos blockchain (devnet).

## Demo

![yolo-ng posts on devnet explorer](https://devnet.blockchain.logos.co/web/explorer/transactions/75cf4647a9dd1359bab4b2866e23702a1fe10a75a0a5709fa566fa8be402584f)

- TX 1: https://devnet.blockchain.logos.co/web/explorer/transactions/75cf4647a9dd1359bab4b2866e23702a1fe10a75a0a5709fa566fa8be402584f
- TX 2: https://devnet.blockchain.logos.co/web/explorer/transactions/edf4036df19c5e751e3c4b4f2386581c9bc291f5328446dcbdf5bfb75f97c5ea

## How it works

```
LogosApp UI
    ↓
yolo-ng headless module (C++ Qt)
    ↓ invokeRemoteMethod (QtRO)
logos-zone-sequencer-module
    ↓ C FFI
zone-sequencer-rs (Rust + zone-sdk)
    ↓ HTTP
Logos blockchain node → devnet
```

### Board identity

Each board is identified by a **name** + **secret**:

```
signing_key = SHA256(name + ":" + secret)  →  Ed25519 seed
channel_id  = signing_key.public_key()     →  32-byte channel identifier
checkpoint  = ~/.local/share/yolo-ng/<hash>.checkpoint
```

Two users with the same name + secret post to the same channel. Different secret = different channel. No key management needed.

## Installation

### Prerequisites

- LogosApp (Nix) installed
- [logos-zone-sequencer-module](https://github.com/jimmy-claw/logos-zone-sequencer-module) installed

### Install yolo-ng

```bash
# Download latest release (includes zone-sequencer-module)
curl -L https://github.com/jimmy-claw/yolo-ng/releases/latest/download/yolo-ng.tar.gz -o /tmp/yolo-ng.tar.gz
tar xzf /tmp/yolo-ng.tar.gz -C /tmp/yolo-ng-install
bash /tmp/yolo-ng-install/install.sh
```

Or manually:
```bash
LOGOS_DIR=~/.local/share/Logos/LogosAppNix

# Headless module
cp yolo_ng_plugin.so $LOGOS_DIR/modules/yolo_ng/
cp modules/yolo_ng/manifest.json $LOGOS_DIR/modules/yolo_ng/

# UI plugin
cp yolo_ng_ui.so $LOGOS_DIR/plugins/yolo_ng_ui/
cp plugins/yolo_ng_ui/manifest.json $LOGOS_DIR/plugins/yolo_ng_ui/
cp -r qml/ $LOGOS_DIR/plugins/yolo_ng_ui/

# Zone sequencer module
cp liblogos_zone_sequencer_module.so $LOGOS_DIR/modules/zone_sequencer_module/
cp libzone_sequencer_rs.so $LOGOS_DIR/modules/zone_sequencer_module/
cp zone_sequencer_module/manifest.json $LOGOS_DIR/modules/zone_sequencer_module/
```

### Load in LogosApp

1. Open LogosApp
2. Go to Basecamp → load `liblogos_zone_sequencer_module`
3. Open yolo-ng from the app launcher

## Usage

1. Enter a **board name** and **secret** → click Connect
2. Type a post → click Post
3. Post is stored locally and inscribed on the Logos blockchain

The first post on a new board creates the channel. Subsequent posts chain off the previous inscription via checkpoint.

## Building

```bash
# Build everything
nix build .#lgx        # → result/yolo-ng.lgx (full bundle)
nix build .#headless-plugin  # → headless .so only
nix build .#ui-plugin        # → UI .so only
```

Requires nixpkgs `e9f00bd8` (Qt 6.9.2).

## Dependencies

| Module | Repo | Purpose |
|--------|------|---------|
| logos-zone-sequencer-module | [jimmy-claw/logos-zone-sequencer-module](https://github.com/jimmy-claw/logos-zone-sequencer-module) | Zone inscription Qt plugin |
| zone-sequencer-rs | [jimmy-claw/zone-sequencer-rs](https://github.com/jimmy-claw/zone-sequencer-rs) | Rust FFI wrapping zone-sdk |
| kv_module | logos-co/logos-kv-module | Local post storage |

## Known limitations

- `liblogos_zone_sequencer_module` must be manually loaded in LogosApp before using yolo-ng (dependency auto-loading not yet working)
- Node URL is hardcoded to Pi5 (`192.168.0.209:8080`) — configurable node support coming
- No post reading from chain yet (ZoneIndexer not implemented) — posts only visible locally after fresh install
