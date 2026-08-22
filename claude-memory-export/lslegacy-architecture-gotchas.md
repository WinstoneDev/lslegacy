---
name: lslegacy-architecture-gotchas
description: "Two non-obvious LSLegacy architecture facts that matter for any future work touching modules or events: only the root fxmanifest.lua is live (per-module ones are dead), and Shared.Anticheat.WhitelistedEvents must stay in sync with client-registered event names."
metadata:
  type: project
---

**lslegacy runs as a single monolithic FiveM resource.** Everything is loaded through the root
`fxmanifest.lua` — there is no per-module resource boundary. A handful of modules (`farm`, `ltd`,
`mdt`, `mecanicien`, `police`, `pompiers`, `samu`) used to have their own `fxmanifest.lua` as a
leftover from an earlier standalone-resource architecture; these were dead (zero effect on
loading) and were removed during [[lslegacy-refactor-progress]] LOT 16bis, after the user caught
me editing them as if they were live and clarified the architecture.

**Why it matters:** if a module folder ever has a `fxmanifest.lua` again (e.g. copy-pasted from
another project, or restored by accident), don't assume it's part of the actual load path — check
whether its files are also listed in the root `fxmanifest.lua`'s `client_scripts`/
`server_scripts`/`shared_scripts`. If they are, the module-level manifest is almost certainly
dead weight, not a second source of truth.

---

**`Shared.Anticheat.WhitelistedEvents`** (`shared/shared.lua`) is a security allowlist of every
legitimate **client-registered** event name (`LSLegacy.Events.Register`/`AddHandler` on the
client side, or `LSLegacy.RegisterClientEvent`) — the anticheat treats anything not in this list
as suspicious. It does **not** cover server-registered events.

**Why it matters:** any rename of a client-registered event (or addition of a new one) that
forgets to update this list will make the anticheat start flagging a perfectly legitimate feature
as tampering — a real risk of false-positive kicks in production, not just a cosmetic doc drift.
Always grep `shared/shared.lua` for the old event string before/after renaming a client event.

A **separate, unrelated list** in the same file, `Shared.Anticheat.Events`, holds detection
*signatures* of other frameworks/cheat menus to ban on sight (`esx_*`, `QBCore:*`,
`chat:server:ServerPSA`, etc.) — these are not our events and must never be "fixed"/renamed to
look like ours, see [[lslegacy-lot-full-migration]] for the related LOT 13 lesson about ESX-looking
strings being ban signatures, not real dependencies.

Similarly, `LSLegacy.Security.RegisterRateLimit('module:action', limit)` calls (per-module, in
each `server/main.lua`) need the same resync when an event they cover gets renamed.

**How to apply, concretely:** after renaming any set of events during LOT 16bis, a final
repo-wide grep for every old event string (not just in event-registration calls, but anywhere —
comments, rate-limit tables, the whitelist) confirmed zero leftovers. Do the same full sweep
after any future event rename, not just a spot-check on the files you remember touching.
