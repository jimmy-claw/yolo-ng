# yolo-ng

A Logos Core module for posting text inscriptions on the Logos blockchain (devnet).

## What it does

yolo-ng lets users post short text messages that get inscribed on the Logos blockchain via the zone-sdk. Each post is permanently recorded on-chain.

## Architecture

```
yolo-ng UI (QML)
    ↓
yolo-ng headless plugin (C++ Qt)
    ↓ invokeRemoteMethod (QtRO)
logos-zone-sequencer-module
    ↓ FFI
zone-sequencer-rs (Rust + zone-sdk)
    ↓ HTTP
Logos blockchain node → devnet
```

## Dependencies

- [logos-zone-sequencer-module](https://github.com/jimmy-claw/logos-zone-sequencer-module) — Logos Core Qt plugin for zone inscription
- [zone-sequencer-rs](https://github.com/jimmy-claw/zone-sequencer-rs) — Rust FFI library wrapping zone-sdk

## Installation

Download the bundle from crib and install:

```bash
tar xzf yolo-ng-v2.tar.gz -C /tmp
bash /tmp/yolo-bundle/install.sh
```

The bundle includes:
- `yolo-ng.lgx` — yolo-ng Logos module
- `liblogos_zone_sequencer_module.so` — zone sequencer Qt plugin
- `libzone_sequencer_rs.so` — Rust FFI library
- `yolo-ng-demo.checkpoint` — pre-seeded checkpoint for the demo channel

## Channel & Keys

yolo-ng uses a deterministic signing key derived from the channel name:

```
channel name: "yolo-ng-demo"
signing key:  SHA256("yolo-ng-demo") = 0151f7d1d029b6c40390f45640006430978940f1af9267c9a831d17b75a7bf27
channel id:   86998c9581ec65d811a88d7edef6adff9daa9b14cd90c2bd20e89b09bc871954 (pubkey of signing key)
```

Channel on devnet: `86998c9581ec65d811a88d7edef6adff9daa9b14cd90c2bd20e89b09bc871954`

## Checkpoint

The zone-sdk requires a checkpoint for chain continuity — without it, inscriptions are rejected by validators. The checkpoint is stored at `/tmp/yolo-ng-demo.checkpoint` and updated automatically after each successful post.

The bundle ships a pre-seeded checkpoint. If lost, the channel must be re-bootstrapped by running `logos-blockchain-node inscribe` once with the same key.

## Building

```bash
nix build .#headless-plugin   # headless C++ plugin
nix build .#lgx               # full .lgx bundle
```

## Repos

- yolo-ng: https://github.com/jimmy-claw/yolo-ng
- zone sequencer module: https://github.com/jimmy-claw/logos-zone-sequencer-module
- zone sequencer Rust FFI: https://github.com/jimmy-claw/zone-sequencer-rs
