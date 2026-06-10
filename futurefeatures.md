# Future features

Ideas worth building, roughly in order. The thread connecting most of them:
the app has a **free, private, on-device model** sitting next to a **growing
log of everything you've asked** — a combination cloud assistants can't
credibly offer, because running inference over personal history either costs
money per query or means shipping that history to a server.

## 1. History as memory

Today history is a dead list. Make it the model's memory.

**v1 (deliberately simple):** when a new question comes in, check past Q&As
for related ones — recency + keyword match, no embeddings — and quietly feed
the best match into the session as extra context. Ask *"what was that flag
for swift build again?"* and it answers from your own past conversation.

**Later, if v1 proves useful:**
- An explicit "ask your history" mode — answer questions *about* past
  conversations ("what did I ask about Carbon hotkeys last week?").
- Semantic matching via `NLEmbedding` (still fully on-device) once keyword
  match stops being good enough.
- Surface related past Q&As in the UI ("you asked something similar on
  May 3") instead of, or in addition to, silent context injection.

**Constraints learned so far:**
- The on-device window is ~4k tokens — recalled context must be budgeted,
  not dumped.
- Should be **on-device-only by default**. The moment recalled history flows
  through the OpenAI fallback, "your history never leaves your Mac" gets an
  asterisk, and that claim is the product's spine.
- Prerequisite: tag each `HistoryItem` with the engine that answered and
  the conversation it belonged to (turns are currently saved as isolated
  rows; group them).

## 2. Graceful context-window overflow

A long conversation eventually overflows the on-device session's ~4k token
window. Today that turn just errors, and the user has to re-summon the box.

**Fix:** catch the overflow error (`exceededContextWindowSize`), ask the
model to summarize the conversation so far, seed a fresh
`LanguageModelSession` with that summary as instructions, and retry the turn.
The user shouldn't notice anything except maybe a subtle "condensed earlier
conversation" hint. Same trick applies to oversized pasted context: summarize
it in a pre-pass instead of truncating at 8k characters.

## 3. Show which engine answered

Tiny trust feature: a subtle badge per answer — "on-device" or "openai" — in
the transcript and in history. In auto mode the user currently can't tell
whether their text left the Mac. Cheap to build (the engine is already pinned
per conversation), and it's the honest version of the privacy story.

## 4. Custom quick actions

`eli5` and `rewrite` are hardcoded. Let users define their own
prompt-prefix buttons (name + template) in Settings. The on-device model
makes habitual one-tap actions free, so people can build muscle memory around
"summarize", "translate to Hindi", "make this a tweet" — whatever their day
actually contains.

## 5. Paste-back for rewrites

The Services flow brings selected text *in*, but answers only come *out* via
copy-paste. For transformation actions (rewrite, fix grammar), add a "replace"
button that puts the result on the pasteboard and — if feasible without new
permissions — pastes it back over the selection. This turns the app from
"ask about text" into "operate on text anywhere".

## 6. Structured quick actions via @Generable

FoundationModels supports guided generation: define a Swift type with
`@Generable` and the model fills it. Quick actions could return structure
instead of prose — extract action items from a pasted email as a checklist,
pull dates/names/amounts from text as fields. On-device only, but it's the
kind of feature that makes the local engine feel *more* capable than the
cloud fallback rather than less.

## 7. History hygiene

Before any memory feature ships, history needs basics it currently lacks:
search in the history window, delete one item, clear all, and storage in a
real file (JSON in Application Support) instead of a UserDefaults string —
which also unlocks export. A privacy-first app should make forgetting as easy
as remembering.

## 8. Tools for the on-device model

FoundationModels has a `Tool` protocol — the model can call app-provided
functions mid-response. The natural first tool is **search-my-history**
(which makes feature #1 something the model decides to do when relevant,
rather than something bolted on every request). Others that stay
on-device: read the clipboard, get the current date/frontmost app for
context. Keep the tool surface tiny and visible.

---

**What we're deliberately not doing yet:** RAG infrastructure, vector
databases, a general "memory engine", multi-model support. Each idea above
should ship as a small concrete instance first and earn its abstraction.
