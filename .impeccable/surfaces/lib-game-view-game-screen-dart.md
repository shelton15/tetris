---
version: 1
slug: "lib-game-view-game-screen-dart"
primary_target: "lib/game/view/game_screen.dart"
related_targets: []
---

Scope: game screen (board, HUD, pause sheet, game-over). Mode: operate. Native adaptive Flutter, phone-first.

Task: play short sessions one-handed; read score/level/lines/next at a glance; pause instantly; restart after game over.

## Direction contract

FORM: canon (category standard, played straight). seed: seed:080c592c9a6ea99e. Quality bar: Apple Arcade casual puzzlers.
THESIS: The board is the hero; chrome is a quiet strip. Refuses neon-on-black arcade glow and the classic piece palette.
OWN-WORLD: Dark graphite well on a near-black ground that follows system dark/light; seven original muted-saturated piece hues (not the classic set), each block a soft-bevel tile with a distinct inner mark so shapes read without colour. System type, tabular figures.
STORY: Score is the biggest number; level, lines and next sit beside it small. Nothing else on screen while playing.
FIRST VIEWPORT: Safe-area HUD row (score left, level·lines, next preview, pause button 44pt), board fills remaining height at integer cell size, centred.
SIGNATURE: Ghost piece as an outline; cleared rows flash then collapse; pause is a native sheet (Cupertino on iOS, Material on Android) with Resume primary and Restart isolated.
