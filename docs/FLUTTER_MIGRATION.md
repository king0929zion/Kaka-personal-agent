# Kaka Android Flutter migration tracker

Goal: fully custom minimalist Android UI, floating capsule nav, Lucide icons, pixel-matched organic avatar profiles. Preserve Expo until verified parity.

## Implemented in the first preview
- Standalone Flutter source tree; Android embedding generated for installed Flutter SDK.
- Health probe, endpoint validation, password login, secure session persistence, Space selection.
- Flat monochrome UI, custom sheets, Chats/Agents/Settings, agent creation and chat.
- RPC thread snapshot, bot/group text send, authenticated SSE subscription and cursor, older message paging.
- File picker and 10 MiB/4 attachment upload guardrails, Markdown rendering and image/text preview.
- 8 organic silhouettes, 16 expression presets, 12 colors, basic breathing/blinking and a local editor.
- Tests and an Android debug APK CI workflow.

## Release blockers — not yet implemented or verified
- Group lifecycle and advanced events, full media previews, sharing and permission handling.
- Speech recognition, TTS, realtime calls, Computer remote controls and keyboard.
- Exact message state reducer and complete cards: tool approvals, choices, MCP and app connection, charts, artifacts, Markdown, code blocks, reactions, quoted replies.
- Remaining Agent lifecycle, routines, reminders, integrations, model credentials/OAuth, account deletion and other settings flows.
- Android push and background notification services, deep links, store signing, update distribution.
- HTML BLOUB 1:1 avatar geometry/3D eye projection, all 15 timed animations, configurable timeline, agent state triggers.
- Server-persisted avatar profile and compatibility with legacy clients.
- Full a11y, localization, physical-device performance and regression testing, auth recovery and network edge cases.

## Migration rules

Do not retire `apps/mobile` or ship Flutter as a production replacement until all release blockers above are cleared. Server owns authorization, validation, and agent behavior. Client should preserve unknown MessageBlock data rather than drop it.

The existing client uses POST /rpc/health (JSON envelope), POST /api/auth/sign-in/email (Better Auth), oRPC /rpc/<name>, SSE POST /rpc/threads/subscribe with Bearer token and x-rakazo-space-id. Check `apps/mobile/lib/api.ts` before changing transport behavior.
