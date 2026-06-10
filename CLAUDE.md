# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

"right here" — a macOS menu-bar AI assistant (SwiftUI, SPM executable, no Xcode project). Summoned with a global shortcut (left ⌥ + right ⌥ + R), it answers questions using Apple's on-device Foundation Models when available, with an OpenAI streaming fallback. No tests; verification is manual via the running app or standalone Swift probe scripts.

## Commands

```sh
swift build                  # debug build (fast check that code compiles)
./build.sh                   # release build + assembles "right here.app" bundle
open "right here.app"        # launch (it's a menu-bar app — look for "right here" in the menu bar)
```

To relaunch after a rebuild: `pkill -f "right here.app/Contents/MacOS/right here"` then `open "right here.app"`. The .app bundle is assembled manually by build.sh (binary + Info.plist); editing Swift sources does nothing to the running app until you rebuild the bundle.

To experiment with FoundationModels API behavior (availability, streaming shape, session memory), write a standalone script and run `swift script.swift` — much faster than going through the app.

## Build constraints

- **Swift 6 language mode** (tools 6.0) — strict concurrency is ON. Two gotchas already hit: extern CFString globals like `kAXTrustedCheckOptionPrompt` are rejected as shared mutable state (use the literal string key), and nested functions do not inherit actor isolation (inline the code or use a closure).
- **Platform floor is macOS 14**, but FoundationModels needs macOS 26. All FoundationModels usage must stay behind `#if canImport(FoundationModels)` + `#available(macOS 26.0, *)` so the app still builds and runs on older macOS. This is why `Conversation.localSession` is stored as `Any` and cast inside availability blocks.
- SourceKit per-file diagnostics ("Cannot find type X in scope") are chronic noise in this repo — same-module types resolve fine; trust `swift build`, not the editor diagnostics.

## Architecture

The engine system is the core. `AIEngine` (in right_here.swift) is auto/onDevice/openAI; `AppState.resolvedEngine` settles `auto` to a concrete engine using `LocalAIService.status`. A `Conversation` (created on the first question of each ask-box summon, discarded on the next summon) **pins** the resolved engine for its lifetime and owns the multi-turn state — a persistent `LanguageModelSession` on-device, a growing messages array for OpenAI. Both engines stream **cumulative snapshots** (each yielded string replaces the previous one, not appends) through `AsyncThrowingStream<String, Error>`.

- `Sources/LocalAIService.swift` — availability check only ("can on-device answer right now, and if not why"); the session itself lives in Conversation. On-device context window is ~4k tokens; pasted context is trimmed to 8k chars.
- `Sources/AIService.swift` — OpenAI SSE streaming client (`URLSession.bytes`, `data:` line parsing). Errors are `LocalizedError` so the UI can show them raw.
- `Sources/Managers/HotkeyManager.swift` — deliberately permission-free: `flagsChanged` monitors (allowed without Accessibility) watch the two Option keys via IOKit device-dependent bits (0x20/0x40), and a Carbon ⌥R hotkey is registered only while both are held. **Do not** "simplify" this to a global keyDown monitor — that requires Accessibility permission, which this design exists to avoid.
- `Sources/right_here.swift` — app entry, `AppState` (windows, history as JSON in UserDefaults, hotkey/services setup).
- `Sources/Views/AskView.swift` — the floating ask box: transcript of `ChatTurn`s, streaming updates by turn id, follow-up input. Each summon posts the `ResetAskView` notification, which cancels in-flight streams and starts a fresh conversation.
- `Sources/Managers/ServiceProvider.swift` + Info.plist `NSServices` — right-click "ask right here" on selected text in any app (build.sh runs `pbs -update` to register).

UI-state gotcha: `@AppStorage` inside an `ObservableObject` does not publish changes — that's why `SettingsView` declares its own `@AppStorage` mirrors of the same defaults keys instead of binding through `AppState`.

Product direction and scoped feature ideas live in `futurefeatures.md`; the privacy rule that shapes them: features touching history should be on-device-only by default.
