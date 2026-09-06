# hxrpc

A cross-platform Discord presence library for Haxe. Real Rich Presence on desktop via native IPC, and a webhook-based status fallback on mobile, where Discord exposes no public API for it.

## Features

- Native Discord IPC on Windows, macOS and Linux — the same protocol the official SDK uses
- Webhook-based "now playing" status on Android and iOS
- Single, target-agnostic API (`rpc.HxRpc`) — no `#if` branching needed in your game code
- Safe no-op fallback on any other target (e.g. HTML5)

## Installation

```bash
haxelib git hxrpc https://github.com/Brenninho123/hxrpc.git
```

Add it to your `project.xml` / `Project.xml`:

```xml
<haxelib name="hxrpc" />
```

## Usage

```haxe
import rpc.HxRpc;

HxRpc.init("YOUR_CLIENT_ID", "https://discord.com/api/webhooks/ID/TOKEN");

HxRpc.setActivity({
    details: "Playing Story Mode",
    state: "Week 3",
    largeImageKey: "menu_bg",
    largeImageText: "Main Menu"
});

HxRpc.clearActivity();
HxRpc.shutdown();
```

- On desktop, `webhookUrl` is ignored — pass `null` or omit it.
- On mobile, `clientId` is unused by the webhook backend but kept for API symmetry with desktop.
- Check `HxRpc.connected` after `init` to confirm a backend actually attached.

## API

| Method | Description |
|---|---|
| `HxRpc.init(clientId, ?webhookUrl):Bool` | Connects the platform-appropriate backend. Returns whether it succeeded. |
| `HxRpc.setActivity(activity:Activity):Bool` | Pushes a new activity/status. |
| `HxRpc.clearActivity():Bool` | Clears the current activity/status. |
| `HxRpc.shutdown():Void` | Disconnects and releases the backend. |
| `HxRpc.connected:Bool` | Read-only. Whether a backend is currently active. |

### `Activity` fields

All fields are optional.

| Field | Type | Notes |
|---|---|---|
| `details` | `String` | Top line of the activity. |
| `state` | `String` | Second line. |
| `startTimestamp` / `endTimestamp` | `Float` | Unix seconds, used for elapsed/remaining time. |
| `largeImageKey` / `largeImageText` | `String` | Desktop only — ignored by the webhook backend. |
| `smallImageKey` / `smallImageText` | `String` | Desktop only — ignored by the webhook backend. |
| `partyId`, `partySize`, `partyMax` | `String` / `Int` | Desktop only — party/group info. |

## Platform support

| Target | Backend | Real profile presence? |
|---|---|---|
| Windows | Native IPC (named pipe) | Yes |
| macOS | Native IPC (unix socket) | Yes |
| Linux | Native IPC (unix socket) | Yes |
| Android | Webhook | No — posts to a channel instead |
| iOS | Webhook | No — posts to a channel instead |
| Other (e.g. HTML5) | None (no-op) | No |

## How the desktop backend works

`discord.native.DiscordIPC` speaks Discord's IPC protocol directly, without depending on the official SDK:

- **Windows** connects to `\\.\pipe\discord-ipc-0` through `discord-ipc-9`, whichever is open.
- **macOS/Linux** tries a unix domain socket named `discord-ipc-0`..`9` under `$XDG_RUNTIME_DIR`, `$TMPDIR`, `$TMP`, `$TEMP`, then `/tmp`, in that order.
- Every message is framed as `opcode (uint32 LE) + length (uint32 LE) + JSON payload`.
- `init` sends the opcode-0 handshake (`{"v":1,"client_id":"..."}`), `setActivity`/`clearActivity` send opcode-1 `SET_ACTIVITY` frames, and `clearActivity` sends one with `activity: null`.

The native glue lives in `src/discord/native/discord_ipc.cpp` and compiles to an `.ndll` via `Build.xml`, wired up through `@:buildXml` on `DiscordIPC.hx` — no manual linking needed in the consuming project.

## Why mobile is different

Discord's Rich Presence — the activity shown on a user's profile — is only ever set by a running process talking to the local desktop client over IPC. There's no public endpoint for a mobile app to set that same field on its own account. `discord.mobile.DiscordWebhook` is a practical substitute, not a workaround: it posts an embed to a Discord channel through an incoming webhook each time `setActivity` runs.

To use it:
1. In your Discord server, go to **Channel Settings → Integrations → Webhooks**.
2. Create a webhook and copy its URL.
3. Pass that URL as the second argument to `HxRpc.init`.

## Building the native extension

The CFFI signatures in `discord_ipc.cpp` use the classic hxcpp API (`value`, `alloc_int`, `DEFINE_PRIM`). Compile against your project's hxcpp version before publishing — macro behavior has drifted slightly across hxcpp releases in the past, so a first build is worth verifying rather than assuming.

## License

MIT
