<p align="center">
  <img src="arts/logo.png" alt="hxrpc logo" width="220">
</p>

<h1 align="center">hxrpc</h1>

<p align="center">
  <a href="https://lib.haxe.org/p/hxrpc"><img src="https://img.shields.io/badge/haxelib-hxrpc-orange.svg" alt="Haxelib"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platforms-windows%20%7C%20macos%20%7C%20linux%20%7C%20android%20%7C%20ios%20%7C%20html5-lightgrey.svg" alt="Platforms">
  <img src="https://img.shields.io/badge/haxe-4.x-blueviolet.svg" alt="Haxe">
</p>

<p align="center">
A cross-platform Discord presence library for Haxe. Real Rich Presence on desktop via native IPC, and a webhook-based status fallback on mobile and web, where Discord exposes no public API for setting profile presence from those environments.
</p>

<p align="center">
<code>discord</code> · <code>rpc</code> · <code>rich-presence</code> · <code>haxeflixel</code> · <code>openfl</code> · <code>webhook</code> · <code>ipc</code>
</p>

---

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [API reference](#api-reference)
- [Advanced usage](#advanced-usage)
- [Platform support](#platform-support)
- [Architecture](#architecture)
- [Extras](#extras)
- [Building the native extension](#building-the-native-extension)
- [License](#license)

## Features

- Native Discord IPC on Windows, macOS and Linux — the same wire protocol the official SDK uses, implemented from scratch with no external native dependency
- Webhook-based "now playing" status on Android, iOS, and HTML5
- Single, target-agnostic entry point (`rpc.HxRpc`) — no `#if` branching needed in your game code
- Granular update methods (`setDetails`, `setState`, `setTimestamps`, `setImages`, `setParty`, `setButtons`) that merge into a cached activity instead of requiring a full object every call
- Connection lifecycle callbacks: `onConnected`, `onDisconnected`, `onError`
- `reconnect()` support using the last-used credentials
- Optional HaxeFlixel visual indicator (`discord.RPCSprite`)
- Safe no-op fallback on any unsupported target

## Installation

```bash
haxelib git hxrpc https://github.com/Brenninho123/hxrpc.git
```

Add it to your `project.xml` / `Project.xml`:

```xml
<haxelib name="hxrpc" />
```

## Quick start

```haxe
import rpc.HxRpc;

HxRpc.onConnected = () -> trace("Discord RPC connected");
HxRpc.onError = (msg) -> trace('RPC error: $msg');

HxRpc.init("YOUR_CLIENT_ID", "https://discord.com/api/webhooks/ID/TOKEN");

HxRpc.setActivity({
    details: "Playing Story Mode",
    state: "Week 3",
    largeImageKey: "menu_bg",
    largeImageText: "Main Menu",
    startTimestamp: Date.now().getTime() / 1000
});
```

- On desktop, `webhookUrl` is ignored — pass `null` or omit it.
- On mobile/web, `clientId` is unused by the webhook backend but kept for API symmetry with desktop.
- Check `HxRpc.connected` after `init` to confirm a backend actually attached.

## API reference

### `rpc.HxRpc`

| Member | Description |
|---|---|
| `init(clientId, ?webhookUrl):Bool` | Connects the platform-appropriate backend. Returns whether it succeeded. |
| `reconnect():Bool` | Disconnects and reconnects using the last `clientId`/`webhookUrl` passed to `init`. |
| `setActivity(activity:Activity):Bool` | Replaces the full activity object and caches it internally. |
| `setDetails(details, ?state):Bool` | Updates just the details/state lines, keeping everything else cached. |
| `setState(state):Bool` | Updates just the state line. |
| `setTimestamps(start, ?end):Bool` | Sets elapsed/remaining time fields. |
| `setImages(largeKey, ?largeText, ?smallKey, ?smallText):Bool` | Desktop-only; ignored by webhook backends. |
| `setParty(partyId, size, max):Bool` | Desktop-only; ignored by webhook backends. |
| `setButtons(buttons):Bool` | Desktop-only; `Array<{label:String, url:String}>`. |
| `clearActivity():Bool` | Clears the current activity/status and resets the cache. |
| `shutdown():Void` | Disconnects and releases the backend. |
| `connected:Bool` | Read-only. Whether a backend is currently active. |
| `onConnected:Void->Void` | Called after a successful `init`. |
| `onDisconnected:Void->Void` | Called when `shutdown` runs on an active connection. |
| `onError:String->Void` | Called on connect/update failures, with a human-readable message. |

### `discord.Activity`

All fields are optional.

| Field | Type | Notes |
|---|---|---|
| `details` | `String` | Top line of the activity. |
| `state` | `String` | Second line. |
| `startTimestamp` / `endTimestamp` | `Float` | Unix seconds, used for elapsed/remaining time. |
| `largeImageKey` / `largeImageText` | `String` | Desktop only. |
| `smallImageKey` / `smallImageText` | `String` | Desktop only. |
| `partyId`, `partySize`, `partyMax` | `String` / `Int` | Desktop only. |
| `buttons` | `Array<{label:String, url:String}>` | Desktop only, up to 2 per Discord's own limit. |

## Advanced usage

### Granular updates

```haxe
HxRpc.setDetails("In a match");
HxRpc.setState("Ranked - Diamond");
HxRpc.setTimestamps(Date.now().getTime() / 1000);
HxRpc.setButtons([{label: "Join server", url: "https://discord.gg/yourinvite"}]);
```

Each call merges into the internally cached `Activity` and re-sends the full object, so fields you set earlier are preserved.

### Reconnecting after a dropped session

```haxe
HxRpc.onDisconnected = () -> {
    haxe.Timer.delay(() -> HxRpc.reconnect(), 5000);
};
```

### Forcing the webhook backend regardless of target

Useful for testing the mobile/web code path from a desktop build.

```haxe
import mobilerpc.DiscordMobile;

DiscordMobile.init("https://discord.com/api/webhooks/ID/TOKEN");
DiscordMobile.update("Testing webhook status");
```

## Platform support

| Target | Backend | Real profile presence? |
|---|---|---|
| Windows | Native IPC (named pipe) | Yes |
| macOS | Native IPC (unix socket) | Yes |
| Linux | Native IPC (unix socket) | Yes |
| Android | Webhook (`discord.mobile.DiscordWebhook`) | No — posts to a channel instead |
| iOS | Webhook (`discord.mobile.DiscordWebhook`) | No — posts to a channel instead |
| HTML5 | Webhook (`discord.web.WebRPC`) | No — posts to a channel instead |
| Other | None (no-op) | No |

## Architecture

```
rpc.HxRpc              -- public facade, target dispatch, activity cache, callbacks
  |
  +-- discord.native.DiscordIPC   (windows / mac / linux)
  +-- discord.mobile.DiscordWebhook  (android / ios)
  +-- discord.web.WebRPC          (js / html5)

discord.Backend   -- shared interface implemented by all three backends
discord.Activity  -- shared data structure passed to setActivity
```

### How the desktop backend works

`discord.native.DiscordIPC` speaks Discord's IPC protocol directly, without depending on the official SDK:

- **Windows** connects to `\\.\pipe\discord-ipc-0` through `discord-ipc-9`, whichever is open.
- **macOS/Linux** tries a unix domain socket named `discord-ipc-0`..`9` under `$XDG_RUNTIME_DIR`, `$TMPDIR`, `$TMP`, `$TEMP`, then `/tmp`, in that order.
- Every message is framed as `opcode (uint32 LE) + length (uint32 LE) + JSON payload`.
- `init` sends the opcode-0 handshake (`{"v":1,"client_id":"..."}`), `setActivity`/`clearActivity` send opcode-1 `SET_ACTIVITY` frames, and `clearActivity` sends one with `activity: null`.

### Why mobile and web are different

Discord's Rich Presence — the activity shown on a user's profile — is only ever set by a process talking to the local desktop client over IPC. There is no public endpoint for a mobile or browser app to set that field on its own account. The webhook backends are a practical substitute, not a workaround: they post an embed to a Discord channel through an incoming webhook each time `setActivity` runs, rather than updating the user's profile.

To use it:
1. In your Discord server, go to **Channel Settings → Integrations → Webhooks**.
2. Create a webhook and copy its URL.
3. Pass that URL as the second argument to `HxRpc.init`.

## Extras

### `discord.RPCSprite` (HaxeFlixel only)

A drop-in `FlxSprite` that changes color based on `HxRpc.connected`, useful as an in-game debug indicator. Compiled only when the `flixel` define is present.

```haxe
var indicator = new discord.RPCSprite(10, 10);
add(indicator);
```

## Building the native extension

`Build.xml` compiles `discord_ipc.cpp` as an `.ndll` via CFFI, wired up automatically through `@:buildXml` on `DiscordIPC.hx` — no manual linking needed in the consuming project. The CFFI signatures use the classic hxcpp API (`value`, `alloc_int`, `DEFINE_PRIM`); compile against your project's hxcpp version before publishing, since macro behavior has drifted slightly across hxcpp releases in the past.

## License

MIT
