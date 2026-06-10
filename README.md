# right here

A tiny macOS menu bar assistant. Select text anywhere, summon a floating ask box, get an answer — without switching apps.

Answers come from **Apple's on-device Foundation Models** when available (private, offline, no API key), with an optional OpenAI fallback for Macs that can't run Apple Intelligence.

## Features

- **Floating ask box** — summon it from anywhere with a global shortcut
- **On-device AI** — uses Apple Foundation Models (Apple Intelligence) on macOS 26+; nothing leaves your Mac
- **OpenAI fallback** — works on older macOS or ineligible hardware with your own API key (`gpt-4o-mini`)
- **Streaming answers** — text appears as it's generated, on both engines
- **Follow-ups** — keep asking in the same box; the conversation carries context until you summon it fresh
- **Ask about selected text** — right-click selected text in any app → Services → *ask right here*
- **Quick actions** — one-tap *eli5* and *rewrite* prompts for pasted context
- **History** — past questions and answers, stored locally

## Requirements

- macOS 14+ (Apple Silicon or Intel) for the OpenAI engine
- macOS 26+ with Apple Intelligence enabled, on Apple Silicon, for the on-device engine
- Xcode 26+ to build

## Build & run

```sh
git clone <this repo>
cd righthere
./build.sh
open "right here.app"
```

The app lives in your menu bar (look for "right here").

## Usage

**Shortcut:** hold **both Option keys** and press **R** (⌥ ⌥ R).

No Accessibility permission needed — the app watches only modifier-key state (which macOS allows freely) and registers a system hotkey for the R press just while both Options are held. It never reads your keystrokes, and ⌥R still types "®" normally everywhere.

You can also select text in any app and choose **Services → ask right here** from the right-click menu to pre-fill it as context.

## Engines

Pick an engine in Settings (menu bar → settings…):

| Mode | Behavior |
|---|---|
| `auto` (default) | On-device when ready, otherwise OpenAI |
| `on-device` | Apple Foundation Models only — no API key, no network |
| `openai` | OpenAI API only — requires your API key |

Settings shows live on-device availability (model downloading, Apple Intelligence off, ineligible hardware) so you always know which engine will answer next.

## Privacy

- **On-device mode:** prompts and context never leave your Mac.
- **OpenAI mode:** prompts and context are sent to the OpenAI API with your key.
- History and your API key are stored locally in the app's preferences.

## Roadmap

Ideas under consideration live in [futurefeatures.md](futurefeatures.md).

## License

[MIT](LICENSE)
