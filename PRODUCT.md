# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

Flutter (Dart), MVVM: plain-Dart model in `lib/game/model`, `ChangeNotifier` view models, widgets as views. No third-party state or game packages.

## Users

Casual players on a phone, playing in short sessions of a few minutes, usually one-handed touch. Keyboard play on desktop/web is supported but secondary.

## Product Purpose

An original falling-block puzzle game: pieces of four squares fall into a 10×20 well; the player moves and rotates them to complete and clear rows. Success is a session that starts instantly, feels responsive under the thumb, and is easy to pause and resume.

## Capabilities and Constraints

- Working title **Cairn** (chosen by Claude at the user's request; changeable). The project folder/package is still named `tetris`.
- Must not use the "Tetris" trademark or imitate its trade dress: no classic piece colours or styling, no Russian-themed presentation, no "Korobeiniki".
- Rules: 7-bag randomiser, wall kicks, ghost piece, levels every 10 lines, classic 100/300/500/800 × level scoring.
- Planned later: high score via `shared_preferences`, sounds, haptics on line clears, hold slot (undecided).

## Evidence on Hand

No art, audio, or brand assets yet. Do not fabricate reviews, player counts, or store claims.

## Product Principles

1. Input never waits: every touch or key acts on the very next frame.
2. Pausing is always one gesture away and automatic when the app is backgrounded.
3. The board is the hero; chrome stays quiet around it.

## Accessibility & Inclusion

Pieces must be distinguishable without colour alone; respect reduced-motion and system text scaling in the HUD.
