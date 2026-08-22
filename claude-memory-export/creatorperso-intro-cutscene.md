---
name: creatorperso-intro-cutscene
description: lslegacy creatorPerso plays a GTA Online-style intro cutscene (MP_INTRO_CONCAT) after character creation; the 7 background passenger peds crash the game on this build.
metadata: 
  node_type: memory
  type: project
  originSessionId: ccaeb531-214a-46cb-93a8-708d6f9d0dd2
  modified: 2026-08-21T14:42:13.827Z
---

`module/creatorPerso/client/cutscene.lua` (lslegacy) plays the native
`MP_INTRO_CONCAT` cutscene right after character creation confirmation,
substituting the real player ped into the scene via `GeneratePed()` /
`RegisterEntityForCutscene`. Adapted from
[Doublox/CutScene](https://github.com/Doublox/CutScene).

**The 7 decorative background passenger peds (created via `CreatePed` +
`SetPedRandomComponentVariation`) crash the game process** on the current
build (`FiveM_b3407`, native `SET_PED_RANDOM_COMPONENT_VARIATION` /
`0xC8A9481A01E63C28`). Confirmed by isolating: disabling passenger creation
(`SKIP_PASSENGERS = true` in cutscene.lua) fixed it; the substitution of the
real player ped (`GeneratePed`) alone does not crash.

**Why:** cross-checked against two other public implementations of this same
script (identical code, no extra guards) — they don't fix it either, and a
Cfx.re forum thread confirms ped-replacement inside `mp_intro_concat`
specifically has been an unresolved community pain point for years. This
looks like a build-specific fragility of the technique itself, not a bug in
our adaptation.

**How to apply:** `SKIP_PASSENGERS` is intentionally left `true` in
`cutscene.lua` — do not re-enable the passenger loop without testing in-game
first. If someone wants the background passengers back, treat it as a
separate risky experiment, not a quick fix.
