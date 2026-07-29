# MIRROR LOGIC — PRODUCT REQUIREMENTS DOCUMENT
### Full Game Design, Technical & Production Specification
**Prepared for:** Skypion Technology — Development Handoff (Cursor AI Implementation Ready)
**Genre:** 2D Physics-Based Optical Puzzle Game
**Platform:** Android & iOS (Flutter, Offline-First, Portrait Mode, Single Player)
**Document Status:** v1.0 — Implementation Baseline
**Document Owner:** Product & Game Design

---

## How to Read This Document

This PRD is written to be handed directly to an AI coding agent (Cursor AI) or a human engineering team with zero additional context. Every mechanic, system, screen, and data structure is defined at implementation-level detail. Requirement IDs follow the pattern `[CATEGORY-###]` (e.g., `FR-001`, `MIR-014`, `ECO-007`) so they can be tracked in a backlog tool. Priorities use **P0 (Launch Blocker)**, **P1 (Launch Important)**, **P2 (Post-Launch)**, **P3 (Future/Nice-to-have)**.

---

# 1. Executive Summary

Mirror Logic is a 2D physics-based optical puzzle game built in Flutter for Android and iOS. Players rotate wall-mounted mirrors to redirect a continuous, real-time laser beam through a room (and later, through entire multi-room buildings) until it strikes a Target Crystal. The game is grounded in real optical physics — angle of incidence equals angle of reflection — with no fantasy mechanics, no arcade abstractions, and no unrealistic mirror behavior. The core loop is built for "Aha!" moments driven by spatial logic rather than reflexes or randomness.

The product is designed offline-first, with hundreds of handcrafted levels organized into thematic chapters, a creative sandbox "Building Mode" allowing players to construct their own multi-room beam puzzles, a fair and non-punishing hint system, a lightweight economy (coins, stars), achievements, and a monetization model built on rewarded ads and optional IAP that never gates core progression behind a paywall.

This document is the single source of truth for design, engineering, art, QA, and business stakeholders. It is written to be handed directly to an AI coding agent for implementation, and therefore favors precision and completeness over brevity.

---

# 2. Vision Statement

**"A puzzle game that respects the player's intelligence."**

Mirror Logic exists to deliver the purest form of spatial-logic satisfaction: a single beam of light, real physics, and a mind that must out-think geometry. Every design decision — from mirror hinge constraints to hint pacing to monetization — is filtered through one question: *does this respect the player's intelligence and time?* The long-term vision is for Mirror Logic to become the definitive "calm but deeply cerebral" puzzle franchise, recognized for elegance the way games like *The Witness*, *Monument Valley*, and *Snakebird* are recognized in their categories — but accessible to a casual mobile audience.

---

# 3. Business Goals

| ID | Goal | Metric | Target (Year 1) |
|---|---|---|---|
| BIZ-001 | Establish a sustainable premium-casual puzzle IP | D1/D7/D30 retention | 40% / 18% / 8% |
| BIZ-002 | Monetize without harming perceived fairness | ARPDAU | $0.03–$0.06 |
| BIZ-003 | Drive organic growth via shareability of Building Mode | % of installs from organic/referral | ≥ 35% |
| BIZ-004 | Build a scalable content pipeline | Levels shippable per month post-launch | 40–60 |
| BIZ-005 | Establish Skypion Technology as a credible mobile game studio | Featuring on Play Store / App Store | 1+ editorial feature in first 6 months |
| BIZ-006 | Minimize churn from unfair monetization | Uninstall rate attributable to ads/IAP complaints (store reviews) | < 5% of 1–2 star reviews |

---

# 4. Product Goals

| ID | Goal | Description |
|---|---|---|
| PROD-001 | Deliver a frictionless first-session experience | Player understands core mechanic within 60 seconds without reading text-heavy tutorials |
| PROD-002 | Guarantee every level is solvable and has exactly one intended logical path (though possibly multiple valid physical solutions) | See §35 Puzzle Design Guidelines |
| PROD-003 | Ship with 300+ handcrafted levels at launch | Across 6–8 chapters |
| PROD-004 | Ship Building Mode as a headline differentiator | Multi-room sandbox, shareable configurations (post-launch social layer) |
| PROD-005 | Maintain 60 FPS on 90% of active Android/iOS devices (2019+) | Performance budget defined in §38 |
| PROD-006 | Fully functional offline | No feature (other than optional cloud sync/leaderboards) requires connectivity |
| PROD-007 | Accessible to colorblind and motor-impaired players | See §40 |

---

# 5. Problem Statement

The mobile puzzle genre is saturated with games that either (a) dilute logic puzzles with heavy-handed monetization and forced ad interruptions, or (b) fail to deliver genuine "aha" difficulty progression, relying instead on padding, timers, or artificial lives systems. Optical/mirror-reflection puzzles specifically are an underserved niche: most existing titles use simplified grid-based reflection (90° snapping) rather than realistic continuous-angle rotation, and few offer a creative/sandbox extension of the core mechanic. There is a clear gap for a physics-accurate, respectfully-monetized, offline-first mirror puzzle game with a strong content pipeline and a sandbox mode that extends replayability beyond the handcrafted level list.

---

# 6. Target Audience

**Primary Audience:** Casual-to-midcore puzzle players aged 18–45, global (with initial GTM focus on US, UK, Canada, Australia, Western Europe), who play puzzle games such as *Two Dots*, *Monument Valley*, *The Witness* (mobile-adjacent), *Snakebird*, or physics puzzlers like *Bridge Constructor* and *Cut the Rope*.

**Secondary Audience:** STEM-interested players and students (the game has organic appeal to physics/optics-curious players, and can be marketed with a light "real physics" educational angle), and sandbox/creative-mode enthusiasts (similar audience to *The Incredible Machine*, *Baba Is You* fans).

**Demographics:**
- Age: 16–55, core 25–40
- Gender: Balanced skew, slight lean toward players who also play word/logic games (historically more balanced than action genres)
- Device: Mid-to-high-end Android and iOS devices; game must remain playable on 3-year-old mid-tier hardware
- Session behavior: Short, frequent sessions (commute, break-time) interspersed with occasional long Building Mode sessions

---

# 7. Player Personas

### Persona 1 — "Logical Lena" (Core Persona)
- 29, marketing coordinator, plays *Two Dots* and *Wordle* daily
- Wants a satisfying brain-teaser during commute
- Hates forced ads and lives systems
- Success metric: completes 3–5 levels per session, returns daily

### Persona 2 — "Builder Ben"
- 34, software engineer, enjoys systems and sandbox games (*Factorio*, *Baba Is You*)
- Will spend disproportionate time in Building Mode
- Low monetization value per session but high retention/evangelism value
- Success metric: creates and shares custom room layouts

### Persona 3 — "Casual Carla"
- 42, plays mobile games occasionally, low tolerance for complexity
- Needs strong onboarding and a forgiving hint system
- Primary IAP/ad-watch persona (accepts rewarded ads for hints)
- Success metric: completes onboarding + Chapter 1 without frustration

### Persona 4 — "Completionist Chris"
- 24, achievement hunter, plays until 100% completion
- Drives long-tail engagement and late-game monetization (cosmetic/building content)
- Success metric: unlocks all achievements, plays Daily Challenges

---

# 8. User Journey

| Stage | Player State | Key Touchpoints | Design Response |
|---|---|---|---|
| Discovery | Sees store listing/ad | Screenshots, short video of beam solving | Emphasize satisfying "click" of beam completing |
| Install → First Open | Curious, low patience | Splash → Onboarding | Onboarding must produce first "aha" within 60s |
| Early Session (Ch.1–2) | Learning mechanics | Level Selection, Gameplay, Level Complete | Gentle difficulty ramp, generous free hints |
| Habit Formation (Day 2–7) | Returning daily | Main Menu, Offline Progress, Daily Challenge | Reason to return: progress state, streaks |
| Mid-Game (Ch.3–5) | Invested | Achievements, Statistics, Store | Introduce monetization softly (rewarded hints) |
| Mastery (Ch.6+) | Skilled | Building Mode, harder chapters | Sandbox unlocked as reward for mastery |
| Late-Game/Retention | Completionist or lapsed | Daily Challenge, new content updates | Live-ops content cadence sustains engagement |
| Churn/Win-back | Inactive | Push notification (opt-in), offline progress | Non-intrusive win-back notification, no guilt mechanics |

---

# 9. Game Overview

Mirror Logic is played in strict portrait orientation. Each level presents a room (or, in later chapters, a set of connected rooms) containing a fixed **Light Source**, one or more **wall-mounted Mirrors**, static **Obstacles/Walls**, and one or more **Target Crystals**. The player rotates mirrors by dragging; the laser beam recalculates its full reflection path in real time on every frame of interaction — there is no "submit" or "fire" action. A level is solved the instant the beam simultaneously satisfies all target conditions (see §15 Win Conditions).

The game has no combat, no timers by default (timers are reserved for optional bonus-star objectives, never for failure), and no random elements in core puzzle levels — every level has a deterministic, discoverable logical solution.

---

# 10. Core Gameplay Loop

```
ENTER LEVEL
   → Observe room layout, light source, mirrors, target(s)
   → Form hypothesis about mirror angles
   → Rotate mirror(s) via drag gesture
   → Beam recalculates in real time
   → Observe beam path change
   → Iterate (rotate other mirrors, refine angles)
   → [Optional] Request hint if stuck
   → Beam reaches all Target Crystals simultaneously
   → LEVEL COMPLETE (stars awarded based on performance criteria)
   → Return to Level Select OR Auto-advance to next level
```

**Meta Loop (session-to-session):**
```
OPEN APP → Offline Progress (if any) → Main Menu
   → Choose activity: Continue Chapter | Building Mode | Daily Challenge
   → Play 3–10 levels or one sandbox session
   → Check Achievements/Statistics (optional)
   → Close app
   → [Push notification triggers return, opt-in only]
```

---

# 11. Core Mechanics

| ID | Mechanic | Description |
|---|---|---|
| MECH-001 | Continuous Real-Time Beam Simulation | Beam path is recalculated every frame while any mirror is being dragged, and once on level load. No discrete "steps." |
| MECH-002 | Mirror Rotation via Drag | Player touches a mirror and drags in an arc; the mirror rotates around its fixed hinge point, constrained to its allowed angular range. |
| MECH-003 | Reflection Physics | Angle of incidence = angle of reflection, computed relative to the mirror's surface normal. See §26. |
| MECH-004 | Beam Occlusion | Any opaque obstacle or wall segment blocks/absorbs the beam at the point of contact (beam terminates there unless it's a mirror). |
| MECH-005 | Multi-Segment Beam Path | A beam may reflect off multiple mirrors in sequence before reaching a target, being absorbed, or exiting the play area. |
| MECH-006 | Simultaneous Multi-Target Requirement | Levels may require multiple Target Crystals to be lit at once (via beam splitters in later chapters, or multiple light sources). |
| MECH-007 | No Fail State by Default | Standard levels cannot be "failed" — only solved or left incomplete. Failure only exists in optional bonus/challenge level types (see §32). |
| MECH-008 | Deterministic Solvability | Every level ships with a verified, unique-family solution (see §35). |

---

# 12. Mirror Mechanics

Mirrors are the central interactive object. Full specification:

**MIR-001 — Mounting:** Every mirror is mechanically hinged to a fixed pivot point (`hingePosition: Vector2`) attached to a wall, floor bracket, or ceiling bracket, matching real-world wall-mounted mirror hardware. The hinge position is immutable during gameplay (mirrors never translate, only rotate).

**MIR-002 — Rotation Range:** Each mirror has a `minAngle` and `maxAngle` (in degrees, relative to its mounting wall) defining its physical rotation constraint. A mirror mounted flush against a wall cannot rotate a full 360°; typical constraint range is 0°–180° relative to the wall plane (i.e., it can sweep from parallel-to-wall on one side to parallel-to-wall on the other, but cannot pass through the wall). Default: `minAngle = 5°`, `maxAngle = 175°` from wall-parallel, tunable per mirror instance.

**MIR-003 — Rotation Input:** Player drags anywhere on the mirror sprite; rotation angle is computed from the vector between the hinge point and the current touch position, clamped to `[minAngle, maxAngle]`.

**MIR-004 — Snap Increments (Difficulty-Dependent):** Early chapters use `snapIncrement = 1°` (near-continuous, feels analog). Some level types introduce discrete snapping (e.g., `15°` or `45°`) as a distinct puzzle sub-mechanic requiring precision planning rather than trial-and-error sliding — see §32 Level Types.

**MIR-005 — Two-Sided vs One-Sided Mirrors:** Two mirror subtypes:
- *Standard Mirror (reflective both sides):* reflects beam regardless of which face it strikes.
- *One-Way Mirror (later chapters):* reflective on one face only (marked visually); beam passes through or is absorbed on the non-reflective face, per level design (default: passes through as plain glass, no refraction, for simplicity — see MIR-006 assumption).

**MIR-006 — Assumption (documented):** To preserve realism without introducing refraction complexity, one-way mirrors are modeled as fully reflective on the coated face and fully transparent (zero refraction/displacement) on the uncoated face. This is a deliberate simplification; true glass refraction is out of scope (see §93 Features That Should Never Be Added).

**MIR-007 — Mirror Length/Surface:** Mirrors have a finite `length` (in world units). A beam striking outside the mirror's physical extent (i.e., missing the reflective surface) is absorbed by the mount/wall behind it, not reflected. This creates precision-based puzzles.

**MIR-008 — Locked Mirrors:** Some level designs include mirrors that are pre-set and cannot be rotated by the player (`isLocked: true`), used to control difficulty and teach specific reflection angles.

**MIR-009 — Mirror Types Summary Table:**

| Type | Rotatable | Reflective Faces | Introduced |
| --- | --- | --- | --- |
| Standard Mirror | Yes | Both | Chapter 1 |
| Locked Mirror | No | Both | Chapter 1 (teaching) |
| One-Way Mirror | Yes | One | Chapter 3 |
| Beam Splitter Mirror | Yes | Both (splits beam) | Chapter 4 |
| Rotating-Speed-Limited Mirror (heavy/stiff hinge, future) | Yes (slow) | Both | Post-launch |

---

# 13. Light Reflection Physics

**PHYS-001 — Fundamental Law:** The engine implements the Law of Reflection: the angle of incidence (θᵢ), measured from the surface normal, equals the angle of reflection (θᵣ), also measured from the surface normal, and both rays (incident and reflected) lie in the same plane (trivial in 2D).

**PHYS-002 — Vector Reflection Formula:** Given incoming beam direction vector **d** (normalized) and mirror surface normal **n** (normalized), the reflected direction **r** is computed as:

```
r = d - 2 * (d · n) * n
```

This is the standard reflection formula and must be used verbatim in the physics engine implementation (see §77).

**PHYS-003 — Beam is a Ray, Not a Particle:** The beam is simulated as an infinite-length ray per segment, raycast against all scene colliders (mirrors, walls, obstacles, crystals) to find the nearest intersection point each segment, then reflected (if it hit a mirror) or terminated (if it hit an absorptive surface or crystal).

**PHYS-004 — Maximum Bounce Count:** To prevent infinite loops (e.g., two parallel mirrors reflecting a beam back and forth forever) and to bound compute cost, the simulation enforces `MAX_BOUNCES = 24` per beam per frame. If exceeded, the beam is terminated and rendered as "lost" — this scenario should never occur in a properly designed level (see QA checklist §79) but is a required safety guard.

**PHYS-005 — Beam Speed/Instantaneity:** The beam is treated as travelling at effectively infinite speed within a frame (i.e., it's a static geometric raycast recalculated per frame), not simulated as a moving particle over time. This matches real-world laser behavior at the timescales relevant to gameplay and avoids unnecessary simulation complexity.

**PHYS-006 — No Diffraction, No Refraction, No Beam Attenuation:** Explicitly out of scope for v1 to preserve clarity and readability of puzzles (documented assumption).

---

# 14. Game Rules

| ID | Rule |
|---|---|
| RULE-001 | The beam originates from exactly one active Light Source per standard level (multiple sources introduced in later chapters as a distinct mechanic). |
| RULE-002 | The beam path is fully determined by the current rotation state of all mirrors in the scene — there is no hidden state or randomness. |
| RULE-003 | A level is solved when 100% of required Target Crystals are simultaneously illuminated by the beam for a continuous duration of `HOLD_TIME = 0.4s` (see RULE-004). |
| RULE-004 | The 0.4s hold requirement prevents accidental "flicker" solves while a player is still actively dragging a mirror through the correct angle, ensuring the solve state feels intentional. |
| RULE-005 | Obstacles fully absorb the beam; the beam does not pass through, bend around, or partially transmit through obstacles. |
| RULE-006 | Mirrors cannot occupy the same hinge point as another mirror; layout validation enforced at level-authoring time, not runtime. |
| RULE-007 | The player may rotate any unlocked mirror at any time, in any order, unlimited times, with no move limit in standard levels. |
| RULE-008 | Building Mode has no win/fail condition; it is a free sandbox. |

---

# 15. Win Conditions

| ID | Condition | Applies To |
|---|---|---|
| WIN-001 | Beam continuously illuminates all required Target Crystal(s) for `HOLD_TIME = 0.4s` | All standard levels |
| WIN-002 (3-Star) | Solved using ≤ `parMirrorMoves` net rotations (efficiency-based, not attempt-based — see §29) | Star-rated levels |
| WIN-003 (Bonus) | Solved within `parTimeSeconds` (optional bonus objective, not required for base completion) | Timed bonus levels only (§32) |
| WIN-004 | All Target Crystals lit simultaneously (not sequentially) when multiple crystals are required | Multi-target levels |

**Star Rating Formula (default):**
- 1 Star: Level completed at all (WIN-001 met)
- 2 Stars: Completed without using a hint
- 3 Stars: Completed without a hint AND within an efficient move/time threshold defined per-level in level JSON (`threeStarThreshold`)

This formula deliberately avoids punishing exploration — the player is never penalized for rotating mirrors experimentally, only for hint usage and excessive session time on the 3rd star, preserving the "no artificial difficulty" philosophy from the design brief.

---

# 16. Failure Conditions

**Design Decision (documented):** Per the original design brief and puzzle-genre best practice, **standard puzzle levels have no failure state.** Players cannot "lose" — they can only remain unsolved. This eliminates frustration, life systems, and punitive mechanics entirely, consistent with §93 (Features That Should Never Be Added).

| ID | Condition | Result |
|---|---|---|
| FAIL-001 (Optional, Bonus Objective Only) | Timed bonus levels: `parTimeSeconds` exceeded | Base level remains completable; only the bonus star/reward is forfeited. Never blocks progression. |
| FAIL-002 | N/A — no move limit, no lives, no energy system exists in this product | — |

This is a deliberate and important design decision: **there is no lives/energy system anywhere in Mirror Logic.** This must not be added by engineering or monetization teams without a full design review (see §93).

---

# 17. Player Controls

| ID | Input | Action |
|---|---|---|
| CTRL-001 | Single-finger drag on a mirror | Rotates mirror around its hinge, clamped to its angle range |
| CTRL-002 | Single tap on Pause icon | Opens Pause Menu |
| CTRL-003 | Single tap on Hint icon | Opens Hint System Overlay |
| CTRL-004 | Single tap on Reset icon | Resets all mirrors in current level to their initial (level-start) angles |
| CTRL-005 | Pinch gesture (Building Mode only) | Zooms camera in/out |
| CTRL-006 | Two-finger drag (Building Mode only) | Pans camera across connected rooms |
| CTRL-007 | Long-press on a mirror (Building Mode only) | Opens object inspector (rotation lock, delete, duplicate) |

No swipe, shake, tilt, or multi-touch-combo gestures are used in core gameplay — controls must remain accessible to all motor abilities (see §40).

---

# 18. Input System

**INPUT-001 — Hit Testing:** Each mirror exposes a touch-hit polygon (slightly padded beyond its visual bounds by `8dp` to improve touch accuracy on small screens — a common mobile UX best practice, "fat finger" compensation).

**INPUT-002 — Drag-to-Angle Mapping:** On `PointerDown` over a mirror's hit area, the system records the offset between the touch point and the mirror's current handle position. On `PointerMove`, the new angle is computed as `atan2(touch.y - hinge.y, touch.x - hinge.x)`, converted to the mirror's local rotation space, and clamped to `[minAngle, maxAngle]`.

**INPUT-003 — Multi-Touch Isolation:** Only one mirror may be actively dragged per touch pointer; the system supports simultaneous multi-mirror dragging with two fingers as a P2 feature (not required for launch, but the architecture must not preclude it — use per-pointer gesture recognizers, not a single global gesture arena winner).

**INPUT-004 — Debounce/Smoothing:** Raw touch input is smoothed with a light exponential moving average (`alpha = 0.35`) to avoid jittery beam rendering on noisy touch input, while keeping perceptible input lag under 16ms (1 frame at 60fps).

**INPUT-005 — Haptic Feedback:** Light haptic pulse (`HapticFeedback.selectionClick` equivalent) fires when: (a) a beam newly strikes a previously-unlit Target Crystal, (b) a level solve is confirmed, (c) a mirror snaps to a "notable" angle in snap-mode levels. Haptics are togglable in Settings.

---

# 19. Gameplay States

| State | Description | Entry | Exit |
|---|---|---|---|
| `LevelLoading` | Assets/level JSON parsing | Level selected | Assets ready |
| `LevelIntro` | Optional camera pan/intro beat for first-time level types | LevelLoading complete | Player first touch or auto-timeout (1.5s) |
| `Playing` | Core interactive state | LevelIntro complete | Win condition met, or Pause triggered |
| `Paused` | Simulation frozen, Pause Menu shown | Pause tapped | Resume tapped |
| `HintActive` | Hint overlay shown, simulation frozen or dimmed | Hint tapped | Hint dismissed |
| `Solved` | Win condition met, beam locked in solved state, solve VFX playing | HOLD_TIME satisfied | Level Complete screen shown |
| `LevelComplete` | Results/rewards screen | Solved animation complete | Next/Replay/Exit selected |

State machine must be explicit and centrally managed (e.g., a `GameplayStateNotifier` in Riverpod) — no scattered boolean flags (`isPaused`, `isSolved`, etc.) across widgets.

---

# 20. Game Objects

| Object | Description | Key Properties |
|---|---|---|
| `LightSource` | Fixed emitter of the beam | `position`, `direction` (fixed or player-rotatable in special levels), `color` (cosmetic, future) |
| `Mirror` | Rotatable reflective object | `hingePosition`, `length`, `currentAngle`, `minAngle`, `maxAngle`, `isLocked`, `type` |
| `TargetCrystal` | Win-condition object | `position`, `requiredHoldTime`, `isLit` (runtime), `groupId` (for multi-crystal simultaneous puzzles) |
| `Obstacle` | Static beam-blocking geometry | `polygonShape`, `isDecorative` (visual-only obstacles that don't block, for scenery) |
| `Wall` | Room boundary, also beam-absorbing | `polygonShape` |
| `DoorPortal` (Building Mode) | Connects beam between adjacent rooms | `linkedRoomId`, `entryPosition`, `entryAngle` |
| `BeamSplitter` (Ch.4+) | Special mirror variant that splits one beam into two | `hingePosition`, `splitRatio` (fixed 50/50 for v1) |


---

# 21. Object Behaviors

| Object | Behavior Rules |
|---|---|
| Mirror | Rotates only around fixed hinge; cannot translate; cannot pass through walls/other geometry; reflects beam per §26 when struck on reflective face |
| Light Source | Emits one continuous ray each frame from `position` in `direction`; never moves during standard gameplay (may be player-aimable in a distinct future level type, documented in §34) |
| Target Crystal | Transitions `unlit → charging → lit` based on continuous beam contact; `charging` state visually fills over `HOLD_TIME`; resets to `unlit` immediately if beam contact breaks before hold completes |
| Obstacle | Fully static; absorbs any beam intersection; no rotation, no interactivity |
| Beam Splitter | On beam contact, emits two child rays at symmetric angles relative to the incoming beam and the splitter's normal (50/50 energy split is cosmetic only — both child beams behave as full-strength beams for puzzle-logic purposes, avoiding "beam gets weaker" complexity) |
| DoorPortal | On beam contact, transfers the beam's exit point/angle as the entry point/angle into the linked room's raycast pass; rendered as continuous beam crossing a doorway visual |

---

# 22. Mirror Behaviors (Extended)

**MIR-010 — Visual Feedback During Drag:** While a mirror is actively being dragged, its surface renders with a subtle highlight/glow to communicate "this is interactive" — communicated via elevation/emphasis only, not via color-coded meaning-bearing cues alone (accessibility, see §40).

**MIR-011 — Angle Readout (Optional/Toggleable):** Advanced players may enable a numeric angle readout (degrees) in Settings > Accessibility for precision-focused players; off by default to preserve the "intuitive, physical" feel.

**MIR-012 — Rest State Persistence:** A mirror's angle persists across pause/resume and app backgrounding within a single attempt at a level; it resets only on explicit Reset action or on re-entering the level fresh.

**MIR-013 — Collision with Other Mirrors:** Mirrors are mounted at different depths/wall positions such that their physical rotation arcs never geometrically overlap another mirror's arc (enforced by level design tooling, not runtime physics) — this avoids needing mirror-vs-mirror collision resolution, a deliberate scope-reduction decision.

**MIR-014 — Locked Mirror Visual Language:** Locked mirrors render with a distinct (non-color-only) visual treatment — e.g., a bolted/riveted frame icon — so colorblind players can distinguish them from rotatable mirrors without relying on color alone.

---

# 23. Light Source

**LS-001:** Exactly one primary `LightSource` per standard level, defined in level JSON with fixed `position` and `direction` (unit vector or degrees).

**LS-002:** The light source is rendered as a fixed wall/ceiling-mounted emitter (art-directed as a stylized lamp/laser diode housing — not a cartoonish "laser gun") to preserve the grounded, realistic tone requested in the design brief.

**LS-003 (Future, Ch.5+):** Rotatable Light Source variant — the source itself can be aimed within a constrained arc by the player, functioning identically to a mirror but as the origin point. Documented here as a planned mechanic, not built at launch (P2).

**LS-004:** Multiple simultaneous light sources are supported by the data model (`level.lightSources: List<LightSource>`) even though v1 content primarily uses one, to avoid a costly data-model migration later.

---

# 24. Target Crystal

**CRY-001:** Visual states: `Unlit` (dim, desaturated), `Charging` (pulsing fill animation over `HOLD_TIME`), `Lit` (bright, particle glow, distinct SFX on transition).

**CRY-002:** `groupId` allows level designs to require crystal *groups* — e.g., "any 2 of these 3 crystals" — represented via `requiredCount` on the group (default: `requiredCount = group.length`, i.e., all must be lit).

**CRY-003:** Crystals do not block or reflect the beam once lit; the beam is considered to terminate at a lit crystal (crystals are not "pass-through" reflectors) — this is a deliberate simplification for legibility (documented assumption).

**CRY-004:** Crystal hit detection uses a small tolerance radius (`hitRadius`) larger than the visual sprite to reduce pixel-perfect frustration on small phone screens.

---

# 25. Laser Rendering

| ID | Requirement |
|---|---|
| REND-001 | Beam renders as a continuous poly-line connecting all reflection points from source to termination, drawn every frame the scene is in `Playing`/`Paused`/`Solved` state |
| REND-002 | Beam has a subtle animated "flow" shader/texture-offset to communicate directionality and energy (not a static flat line) — implemented via a scrolling dash pattern or shader, not literal texture requirement, TBD by art team |
| REND-003 | Beam renders a soft outer glow (bloom-style, cheap approximation via layered semi-transparent strokes — NOT a full post-process bloom pass, for performance) |
| REND-004 | Beam color: default white-cyan (#BFEFFF core, #4FD8FF glow) for accessibility/contrast against dark room backgrounds; NOT solely color-coded for functional meaning |
| REND-005 | Rendering must use a single custom-painted layer (`CustomPainter` in Flutter) per scene, not per-segment widgets, to keep draw calls bounded regardless of bounce count |
| REND-006 | Beam recalculation and rendering must complete within the frame budget defined in §38 even at `MAX_BOUNCES = 24` |

---

# 26. Reflection Mathematics

This section is the authoritative physics specification for implementation.

**Given:**
- Incoming ray direction (normalized): **d** = (dx, dy)
- Mirror surface normal at point of contact (normalized): **n** = (nx, ny)

**Reflection Vector:**
```
dot = d.x * n.x + d.y * n.y
r.x = d.x - 2 * dot * n.x
r.y = d.y - 2 * dot * n.y
```

**Surface Normal Derivation:** A mirror is modeled as a line segment from `hingePosition` extended by `length` along the mirror's current rotation angle. The normal is the perpendicular to this segment, oriented to face the incoming ray (i.e., choose the normal sign such that `dot(d, n) < 0`, ensuring correct reflection regardless of which side the beam approaches from, since mirrors are two-sided by default per MIR-005).

**Raycast-Reflect Loop (pseudocode):**
```
function simulateBeam(source):
    segments = []
    origin = source.position
    direction = source.direction
    bounces = 0
    while bounces < MAX_BOUNCES:
        hit = raycastNearest(origin, direction, allSceneColliders)
        if hit == null:
            segments.add(Segment(origin, origin + direction * FAR_DISTANCE))
            break
        segments.add(Segment(origin, hit.point))
        if hit.object is TargetCrystal:
            registerCrystalHit(hit.object)
            break
        elif hit.object is Mirror and hit.object.isReflectiveFace(hit.point):
            direction = reflect(direction, hit.normal)
            origin = hit.point + direction * EPSILON  // avoid self-intersection
            bounces += 1
        elif hit.object is BeamSplitter:
            childA, childB = computeSplitDirections(direction, hit.normal)
            segments += simulateBeam(Source(hit.point, childA))
            segments += simulateBeam(Source(hit.point, childB))
            break
        else: // Obstacle, Wall, non-reflective mirror face
            break
    return segments
```

**Precision Note:** All angle math must use `double` precision (Dart `double`) with an `EPSILON = 1e-4` offset applied to ray origins after each bounce to prevent self-intersection artifacts (a well-known raycasting pitfall).

---

# 27. Physics Rules

| ID | Rule |
|---|---|
| PHY-R-001 | The simulation is purely kinematic/geometric — there is no rigid-body physics engine required for the core beam mechanic (no gravity, no velocity, no collision response beyond raycasting). |
| PHY-R-002 | A lightweight physics/collision library may still be used for Building Mode object placement (snap-to-grid, overlap prevention) but is NOT used to simulate the beam itself. |
| PHY-R-003 | All spatial calculations occur in a normalized world-unit coordinate space (not raw pixels) to ensure resolution-independent, deterministic physics across devices. |
| PHY-R-004 | The beam simulation is fully deterministic: identical mirror angle inputs always produce an identical beam path, with no floating-point-induced flakiness beyond the defined EPSILON tolerance — required for reliable win-condition detection and QA reproducibility. |

---

# 28. Level Design Philosophy

Every level in Mirror Logic must satisfy the following non-negotiable design tenets:

1. **Single Logical Insight per New Concept:** Each level that introduces a new spatial idea (e.g., "beams can pass behind a mirror's back," "two mirrors can form a periscope") isolates that idea with minimal noise, before combining it with prior concepts.
2. **No Randomness:** Every level is hand-authored and deterministic. No procedural generation is used for core chapter content (procedural generation may power Daily Challenges only — see §16/§50).
3. **Fair Visibility:** All information needed to solve a level is visible on screen at level start (no hidden mirrors, no fog-of-war), respecting the "no artificial difficulty" directive.
4. **Difficulty from Geometry, Not Obfuscation:** Difficulty increases via room complexity, mirror count, precision tolerance, and multi-target requirements — never via tiny hit-boxes, misleading visuals, or unclear rules.
5. **Every Level Solvable in Under 3 Minutes by Target Persona:** Median solve time for a level's intended difficulty band should fall within its band's target range (see §29).
6. **Room for Player Expression:** Where possible, levels should tolerate a small family of equivalent solutions (e.g., ±3° tolerance bands, or symmetric solutions) rather than one pixel-perfect answer, to avoid feeling "solved by luck."

---

# 29. Difficulty Curve

| Chapter Band | Levels | Mirror Count | New Concepts Introduced | Target Median Solve Time |
|---|---|---|---|---|
| Ch.1 (Tutorial/Intro) | 1–20 | 1–2 | Basic rotation, single reflection, target crystal | 15–30s |
| Ch.2 | 21–50 | 2–3 | Multi-bounce paths, obstacles | 30–60s |
| Ch.3 | 51–90 | 3–4 | One-way mirrors, locked mirrors, precision mirrors (finite length) | 45–90s |
| Ch.4 | 91–140 | 3–5 | Beam splitters, multi-target simultaneous | 60–120s |
| Ch.5 | 141–200 | 4–6 | Snap-angle precision puzzles, larger rooms | 90–150s |
| Ch.6 | 201–260 | 4–7 | Multi-room (Building Mode-style) puzzles as curated content | 120–180s |
| Ch.7+ (Post-launch) | 261–320+ | 5–8 | Combined mastery levels, remixed mechanics | 120–240s |

**Difficulty Tuning Rule (BAL-001):** No single level may introduce more than one new mechanical concept AND require more than 4 mirrors simultaneously — compound difficulty spikes must be separated by at least 2 "consolidation" levels that reinforce (not introduce) the new concept at lower mirror count.

---

# 30. Progression System

**PROG-001 — Linear Chapter Gating:** Chapters unlock sequentially; Chapter N+1 unlocks after completing a threshold percentage (default 80%) of Chapter N's levels, not 100%, to avoid full-completion gating frustrating players stuck on one hard level.

**PROG-002 — Level Gating Within a Chapter:** Levels within a chapter unlock strictly sequentially (Level N+1 unlocks on completion of Level N) for narrative/difficulty-curve integrity.

**PROG-003 — Star-Gated Bonus Content:** Optional "Vault Levels" (hidden bonus puzzles, 1–2 per chapter) unlock only when the player has earned a cumulative star threshold in that chapter, rewarding mastery rather than raw completion.

**PROG-004 — Building Mode Unlock:** Building Mode's first room unlocks after completing Chapter 2 (ensures players understand core mechanics before entering the open sandbox); additional rooms unlock via a combination of chapter progress and in-sandbox resource accumulation (see §45 Economy).

**PROG-005 — Progress Persistence:** All progression state persists locally immediately on any state change (see §43 Save System) and does not depend on connectivity.

---

# 31. Chapter Structure

| Field | Description |
|---|---|
| `chapterId` | Unique identifier |
| `title` | Display name (localized) |
| `theme` | Visual/environmental theme (e.g., "Attic Workshop," "Observatory," "Greenhouse") |
| `levelIds` | Ordered list of level references |
| `unlockRequirement` | Prior chapter completion threshold |
| `introSequence` | Optional short non-blocking narrative/visual intro (no forced dialogue-heavy cutscenes — respects "respect the player's time" vision) |
| `vaultLevelIds` | Optional bonus level references (see PROG-003) |

Chapters are themed environmentally (lighting, wall textures, background parallax) but never mechanically gated by "reskinned" difficulty — each theme should feel earned and distinct, avoiding asset-reuse fatigue.

---

# 32. Level Types

| Type | Description | Introduced |
|---|---|---|
| Standard | Core rotate-to-solve puzzle, no fail state | Ch.1 |
| Precision | Finite mirror length + smaller crystal hit tolerance, rewards careful angle control | Ch.3 |
| Multi-Target | Requires 2+ crystals lit simultaneously | Ch.4 |
| Snap-Angle | Mirrors snap to discrete angle increments (15°/45°), turning the puzzle into combinatorial angle-selection rather than analog sliding | Ch.5 |
| Timed Bonus | Optional 3rd-star time objective; base completion never time-limited (see §16) | Ch.5+ |
| Multi-Room | Beam travels through connected rooms via DoorPortals; curated Building-Mode-style content | Ch.6 |
| Daily Challenge (Future) | Procedurally-assembled from a validated "concept + constraint" template library, always verified solvable server-side before serving to a client | Post-launch |

---

# 33. Building Mode

**BUILD-001 — Purpose:** A free-form sandbox where players place light sources, mirrors, obstacles, and crystals across multiple connected rooms, with no win condition, functioning as both a creative tool and (post-launch) a social/sharing feature.

**BUILD-002 — Room Unlocking:** Rooms unlock via a combination of chapter progress (PROG-004) and an in-mode currency, "Blueprint Points," earned through normal gameplay star accumulation (not a separate grind — reuses the core economy, see §45).

**BUILD-003 — Placement Rules:** Grid-assisted but not rigidly grid-locked; objects snap to nearby wall-mount points (procedurally identified valid hinge positions along room perimeters) to guarantee mirrors always look physically mounted, never floating mid-air.

**BUILD-004 — Inter-Room Beam Continuity:** A beam exiting through a `DoorPortal` continues into the linked room at the corresponding entry point/angle, enabling multi-room chains purely through player-built layouts.

**BUILD-005 — Save Slots:** Players may save multiple named layouts per unlocked room-set (local storage; cloud sync optional in Settings).

**BUILD-006 — No Combat/No Fail:** Building Mode has zero win/fail state by design; its only "goal" is successfully routing a beam to a self-placed crystal, which is entirely player-defined and always achievable by the player's own design.

**BUILD-007 (Post-Launch, P2) — Sharing:** Export a room layout as a shareable code/link; import a friend's layout to view/solve as a bonus puzzle. This is the primary organic-growth mechanism referenced in BIZ-003.

---

# 34. Future Expansion Modes

| Mode | Description | Priority |
|---|---|---|
| Rotatable Light Source Levels | See LS-003 | P2 |
| Beam Color Filters | Colored beams that must pass through matching-colored filters (still grounded in real dichroic filter optics, not fantasy) | P3 |
| Cooperative/Async Multiplayer Building Mode | Two players build one shared multi-room structure asynchronously | P3 |
| Weekly Community Puzzle | Dev-curated Building Mode layout as a limited-time challenge with a shared leaderboard | P2 |
| Seasonal Chapters | Themed limited-time chapters (visual reskin + fresh level list), see §85 Roadmap | P1 (post-launch) |

---

# 35. Puzzle Design Guidelines

**PDG-001 — Solvability Verification:** Every level must be verified via the internal Level Validator Tool (see §66/§78) before being marked shippable. The tool brute-force/constraint-solves the level's mirror angle space (within tolerance bands) and confirms at least one solution family exists and that the intended solution matches the designer's authored `intendedSolution` reference within tolerance.

**PDG-002 — No Red Herrings:** All visible mirrors and objects must be relevant to the solution (or clearly, consistently used as recurring "decoy geometry" once players learn that convention in later chapters — never as a one-off cheap trick).

**PDG-003 — Tolerance Bands:** Each mirror's "correct" angle in the intended solution has a tolerance band (`±toleranceDegrees`, default 3°–6° depending on precision level type) to avoid pixel-hunting frustration on touchscreens.

**PDG-004 — Escalation Discipline:** See BAL-001 (§29) — no compound spikes.

**PDG-005 — Playtesting Gate:** No level ships without passing internal playtest by at least 2 testers unfamiliar with the intended solution, confirming median solve time falls within the chapter band's target range (§29).

---

# 36. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | System shall render a real-time-updating laser beam reflecting off all mirrors currently in the scene | P0 |
| FR-002 | System shall allow the player to rotate any unlocked mirror via drag gesture, constrained to its defined angle range | P0 |
| FR-003 | System shall detect win condition per RULE-003/004 and transition to `Solved` state | P0 |
| FR-004 | System shall persist level completion state, star rating, and best performance metrics locally | P0 |
| FR-005 | System shall provide a functioning Hint System per §49 | P0 |
| FR-006 | System shall provide Chapter and Level Selection screens reflecting real-time unlock state | P0 |
| FR-007 | System shall support Building Mode room placement, saving, and beam simulation across connected rooms | P0 |
| FR-008 | System shall calculate and present Offline Progress on app resume, if any offline-accruable content exists | P1 |
| FR-009 | System shall support full app functionality with zero network connectivity (excluding optional cloud sync/IAP/ads) | P0 |
| FR-010 | System shall support Daily Challenge content delivery with server-side solvability pre-validation | P2 |
| FR-011 | System shall track and display Achievements and Statistics per §12/§13 (screen spec) | P1 |
| FR-012 | System shall support Settings changes (audio, language, accessibility, notifications) applied immediately without restart | P0 |
| FR-013 | System shall support IAP purchase flow and rewarded-ad flow with graceful failure handling | P1 |
| FR-014 | System shall support cloud save backup/restore when a player links an account (optional feature) | P2 |

---

# 37. Non-Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| NFR-001 | 60 FPS sustained during gameplay on reference device tier (see §38) | P0 |
| NFR-002 | Cold start to interactive Main Menu in ≤ 2.5s on reference device tier | P0 |
| NFR-003 | App install size ≤ 150MB at launch (before optional asset packs) | P1 |
| NFR-004 | 99.5% crash-free session rate post-launch | P0 |
| NFR-005 | All user-facing strings externalized for localization (no hardcoded UI text) | P0 |
| NFR-006 | WCAG-inspired contrast ratios (≥ 4.5:1) for all UI text | P1 |
| NFR-007 | Data privacy compliance: GDPR, CCPA, Apple ATT prompt handling | P0 |

---

# 38. Performance Requirements

**Reference Device Tiers:**

| Tier | Example Device | Target |
|---|---|---|
| Low | 3-year-old budget Android (e.g., 2–3GB RAM, mid-range SoC) | 30 FPS minimum, no crashes |
| Mid | Mainstream Android/iOS 2–3 years old | 60 FPS sustained |
| High | Current-gen flagship | 60 FPS with all visual effects at max |

**Frame Budget (Mid Tier, 60 FPS = 16.6ms/frame):**

| Subsystem | Budget |
|---|---|
| Beam raycast/reflection simulation | ≤ 2.0ms |
| Rendering (CustomPainter draw) | ≤ 4.0ms |
| Input handling | ≤ 1.0ms |
| UI/widget tree overhead | ≤ 3.0ms |
| Audio/haptics dispatch | ≤ 0.5ms |
| Headroom/buffer | ≥ 6.0ms |

**PERF-001:** Beam simulation must not allocate garbage per-frame (reuse buffers/object pools for segment lists) to avoid GC-induced frame drops, especially relevant given Dart's garbage collector.

**PERF-002:** Building Mode with maximum room count/objects (define `MAX_BUILDING_OBJECTS = 60` per room, `MAX_CONNECTED_ROOMS = 12`) must still hold ≥ 30 FPS on Low tier.

---

# 39. Security Requirements

| ID | Requirement |
|---|---|
| SEC-001 | Local save data shall be checksummed to detect (not necessarily prevent) trivial tampering; game is not competitive/PvP so anti-cheat investment is intentionally low priority (documented scope decision) |
| SEC-002 | IAP receipt validation shall occur via platform-provided verification (Google Play Billing / Apple StoreKit) before granting purchased content; client-only trust is disallowed |
| SEC-003 | No PII shall be stored beyond what's required for optional account linking (email or platform ID only) |
| SEC-004 | All network calls (ads SDK, analytics, cloud sync) shall use HTTPS/TLS exclusively |
| SEC-005 | Ad SDK and analytics SDKs shall be sandboxed to not access data beyond documented scopes; privacy manifest (iOS) and Data Safety form (Android) shall accurately reflect all SDK data collection |

---

# 40. Accessibility Requirements

| ID | Requirement | Priority |
|---|---|---|
| ACC-001 | Colorblind-safe design: no game-critical information conveyed by color alone (locked mirrors, crystal states, etc. all have shape/icon differentiation) | P0 |
| ACC-002 | Adjustable UI text scale (respect OS-level font scaling up to 130%) | P1 |
| ACC-003 | Full functionality achievable via single-finger drag only; no required multi-touch gestures for core progression | P0 |
| ACC-004 | Adjustable touch target padding / "assist mode" with larger hit-boxes and wider tolerance bands (§PDG-003) for motor-impaired players | P1 |
| ACC-005 | Haptics and sound both togglable independently; no essential feedback delivered through only one channel | P0 |
| ACC-006 | Screen-reader/TalkBack/VoiceOver labeling for all menu UI (gameplay canvas itself is exempted as inherently spatial, but a text-description fallback of level objective is provided) | P2 |
| ACC-007 | No reliance on precise timing/reflexes for any required (non-bonus) objective | P0 |

---

# 41. Localization Requirements

**LOC-001:** All UI strings, level names, chapter names, and store copy externalized to ARB/JSON resource files (`flutter_localizations` + `intl` package), zero hardcoded strings in widget code.

**LOC-002:** Launch languages: English, Spanish, Portuguese (BR), French, German, Italian, Japanese, Korean, Simplified Chinese, Turkish, Arabic (RTL support required), Urdu (RTL, given studio's regional relevance), Hindi.

**LOC-003:** RTL layout mirroring required for Arabic/Urdu — UI chrome mirrors, but the gameplay canvas itself (physics/beam rendering) does NOT mirror, since it represents literal spatial geometry, not reading direction.

**LOC-004:** Numeric/date formatting localized per device locale (e.g., star counts, statistics screen). No text-in-textures (all text rendered via localized string widgets, never baked into images) to keep localization pipeline lightweight.

---

# 42. Offline Requirements

**OFF-001:** 100% of core gameplay (all chapters, Building Mode, Hint System using non-rewarded-ad hints, Settings, Statistics, Achievements) functions with zero network connection.

**OFF-002:** Only these features require connectivity, and must degrade gracefully with a clear, non-blocking message when unavailable: Daily Challenge content fetch, Rewarded Ads, IAP purchases, Cloud Save sync, Leaderboards (future).

**OFF-003:** Offline Progress (see §43/§17 screen spec) calculates any time-based accrual (if any economy element is time-based — see §45; by default Mirror Logic's economy is *not* idle/time-based, so this system primarily serves streak/Daily Challenge availability messaging rather than idle-currency accrual, a deliberate design choice to avoid pay-to-skip-waiting patterns).

---

# 43. Save System

**SAVE-001 — Local-First Architecture:** All game state is authoritative on-device (Hive or Isar local NoSQL storage — see §71) and immediately persisted on every meaningful state change (level complete, star earned, currency change, settings change).

**SAVE-002 — Autosave Granularity:** In-progress level mirror-angle state is saved on app background/pause (not necessarily every frame, to avoid I/O overhead) so a player can resume mid-puzzle after an interruption.

**SAVE-003 — Save File Structure:** See §67 Data Models for full schema. Save data is versioned (`saveSchemaVersion: int`) to support safe migrations across app updates.

**SAVE-004 — Corruption Recovery:** On load failure/checksum mismatch, the system attempts recovery from the last known-good auto-backup (a rolling secondary copy written every N saves); if unrecoverable, prompts the player with a clear reset option rather than silently failing.

**SAVE-005 — Cloud Backup (Optional, P2):** When a player opts into account linking, save data syncs to a lightweight backend (Firebase/Supabase — see §68) using last-write-wins with a manual conflict-resolution prompt if divergent local/cloud states are detected (per §17 screen spec).

---

# 44. Progression Saving

**PROGSAVE-001:** Progression data model tracks, per level: `bestStars`, `bestMoveCount`, `bestTimeSeconds`, `hintUsedEver` (bool), `completedAt` (timestamp), `attemptCount`.

**PROGSAVE-002:** Chapter unlock state is derived (computed from level completion data), not stored redundantly, to avoid state-desync bugs — a single source of truth principle.

**PROGSAVE-003:** Building Mode saves are stored as separate entities keyed by `roomSetId` + `slotId`, independent of chapter progression data, allowing them to be backed up/restored independently.

---

# 45. Game Economy

Mirror Logic's economy is intentionally light-touch, in service of BIZ-002 and the "respect the player's time and intelligence" vision. There is no energy/lives system, no idle/time-gated currency, and no pay-to-skip-difficulty mechanic.

| Currency/Resource | Earned Via | Spent On |
|---|---|---|
| **Stars** (see §47) | Level completion performance | Unlocking Vault Levels (PROG-003), cosmetic mirror skins (future) |
| **Coins** (see §46) | Level completion (flat + star bonus), Achievements, Daily Challenge | Hint purchases (in-app currency alternative to rewarded ads), Building Mode room unlock progress, cosmetics |
| **Blueprint Points** | Derived from cumulative Coins spent/earned in a rolling manner OR direct star-milestone rewards (design decision: Blueprint Points are simply Coins re-labeled contextually within Building Mode to avoid excessive parallel-currency complexity — **documented simplification**) | Building Mode room/object unlocks |

**ECO-001 — No Pay-to-Win:** No currency purchase provides a puzzle-solving advantage beyond hints, and hints never reveal the *entire* solution instantly without at least a tiered reveal (§49) — preserving the sense of player accomplishment.

---

# 46. Coins

**COIN-001 — Earn Sources:**

| Source | Amount |
|---|---|
| Level completion (1 star) | 5 coins |
| Level completion (2 stars) | 10 coins |
| Level completion (3 stars) | 20 coins |
| Achievement unlock | 25–200 coins (tiered) |
| Daily Challenge completion | 30 coins + streak bonus |
| Rewarded ad watch (optional, capped) | 15 coins, max 5/day |

**COIN-002 — Spend Sinks:**

| Sink | Cost |
|---|---|
| Hint Tier 1 (highlight relevant mirror) | 10 coins OR 1 rewarded ad |
| Hint Tier 2 (show target angle) | 20 coins OR 1 rewarded ad |
| Building Mode room unlock | 100–500 coins (escalating) |
| Cosmetic mirror frame skin (future) | 50–150 coins |

**COIN-003:** Coins are never sold for real money directly disconnected from value — coin packs (§53) are explicitly priced as a convenience/support-the-devs purchase, not a required unlock path, since all content is earnable through play.

---


# 47. Stars

**STAR-001:** Stars are a mastery-signaling resource, capped per level at 3 (see §15 for earning formula). Total stars across all levels is displayed on the Main Menu and Statistics screen as the primary "how far along am I" metric (more meaningful than raw level count, since it reflects skill, not just attendance).

**STAR-002:** Stars gate Vault Level access (PROG-003) and certain Achievements, but never gate core chapter progression (that's gated by completion, not stars — see PROG-001) to avoid punishing players who complete levels inefficiently.

---

# 48. Achievements

**ACH-001 — Categories:** Progression (e.g., "Complete Chapter 3"), Mastery (e.g., "Earn 3 stars on 50 levels"), Exploration (e.g., "Place 100 objects in Building Mode"), Efficiency (e.g., "Solve a level with zero mirror rotations after reset — i.e., a pre-solved layout, a fun edge-case achievement"), Dedication (e.g., "7-day play streak").

**ACH-002 — Sample Achievement Table:**

| ID | Name | Condition | Reward |
|---|---|---|---|
| ACH-C1-COMPLETE | Apprentice Optician | Complete Chapter 1 | 25 coins |
| ACH-STARS-50 | Precision Novice | Earn 150 total stars | 50 coins |
| ACH-STARS-200 | Precision Master | Earn 600 total stars | 200 coins |
| ACH-NOHINT-25 | Self-Reliant | Complete 25 levels without any hint | 75 coins |
| ACH-BUILD-FIRST | Architect | Save your first Building Mode layout | 25 coins |
| ACH-STREAK-7 | Habitual | Play 7 days in a row | 50 coins |
| ACH-ALL-VAULT | Vault Keeper | Unlock and complete all Vault Levels in a chapter | 100 coins |

**ACH-003:** Achievement claiming is automatic (no manual "claim" friction) unless the reward pool design later requires manual claim for a specific live-ops reason — default is auto-grant with a celebratory toast/notification.

---

# 49. Hint System

The hint system is central to the "respect the player" philosophy — it must never feel punitive to need, and must never fully trivialize the puzzle.

**HINT-001 — Tiered Reveal Structure:**

| Tier | Reveal | Cost |
|---|---|---|
| Tier 0 (Free, always available) | Restates the level's objective in plain language (e.g., "Route the beam through 2 mirrors to reach the crystal on the right wall") | Free |
| Tier 1 | Highlights ONE mirror that is part of the intended solution (visual glow, no angle shown) | 10 coins or 1 rewarded ad |
| Tier 2 | Shows the correct target angle range (±tolerance) for that highlighted mirror as a ghost overlay | 20 coins or 1 rewarded ad |
| Tier 3 (only after Tier 1+2 used on all mirrors) | Auto-solves ONE mirror to its correct angle, leaving the rest to the player | 30 coins (no ad option — capped use to preserve accomplishment) |

**HINT-002 — Cooldown/Fairness:** No hard cooldown timer on hints (never artificially delay a stuck player) — the only gate is the coin/ad cost, and Tier 0 is always instantly available for free.

**HINT-003 — First-Time-Free Grace:** The first hint request on each of the first 10 levels a player encounters is free (Tier 1), specifically to teach the hint system exists without friction, per PROD-001 onboarding philosophy.

**HINT-004 — Never Full-Auto-Solve:** No hint tier ever solves the entire puzzle in one tap; Tier 3 is capped to reveal one mirror at a time, requiring repeated (costly) requests to fully trivialize a level — this is an intentional soft friction to preserve the sense of accomplishment while still ensuring no player is ever permanently stuck.

---

# 50. Daily Rewards

**DR-001 — Structure:** A 7-day cycling calendar (resets after day 7 back to day 1) granting escalating Coin rewards for consecutive-day logins, with no punishment/reset-to-zero for a single missed day (a "streak grace" of 1 missed day per week) to avoid the anxiety-inducing FOMO pattern common in exploitative mobile games.

| Day | Reward |
|---|---|
| 1 | 10 coins |
| 2 | 15 coins |
| 3 | 20 coins |
| 4 | 25 coins |
| 5 | 30 coins |
| 6 | 40 coins |
| 7 | 75 coins + 1 free Hint Tier 3 token |

**DR-002:** Claiming is a single tap from Main Menu, never a forced full-screen interstitial or ad-gated claim.

---

# 51. Monetization

**MON-001 — Guiding Principle:** Monetization must never block core progression. Every monetized element (hints, coin packs, cosmetics, ad-removal) has a free-of-charge path to the same functional outcome, with paid options offering convenience/speed/cosmetics only — reinforcing BIZ-002 and PROD-002.

**MON-002 — Revenue Mix Target (Year 1):** ~55% Rewarded Ads, ~35% IAP (coin packs + ad-removal + cosmetics), ~10% Interstitial/other ad formats (used extremely sparingly — see §52).

---

# 52. Ads

| Ad Type | Placement | Frequency Cap | Notes |
|---|---|---|---|
| Rewarded Video | Hint purchase alternative, Daily Coin bonus, Building Mode room unlock assist | Player-initiated only, max 5/day counted toward coin rewards (no hard block after cap — additional watches simply grant no extra coins, avoiding a frustrating hard wall) | Always opt-in, never forced |
| Interstitial | Optional: shown at most once per session, only after Level Complete on levels divisible by 5, and ONLY if the player has not purchased Ad-Free | Max 1 per session | Never shown mid-gameplay, never shown on first session (respect onboarding), always skippable after 5s |
| Banner Ads | NOT USED | — | Explicitly excluded — banner ads clutter a portrait puzzle UI and contradict the premium-feel vision (§93 candidate) |

**AD-001 — Ad-Free Purchase:** A single IAP (`remove_ads`) permanently disables all Interstitial ads (Rewarded ads remain available, since they are opt-in value-exchange, not intrusive).

---

# 53. In App Purchases

| SKU | Type | Price (USD, indicative) | Contents |
|---|---|---|---|
| `coins_small` | Consumable | $1.99 | 500 coins |
| `coins_medium` | Consumable | $4.99 | 1,500 coins (+15% bonus) |
| `coins_large` | Consumable | $9.99 | 3,500 coins (+30% bonus) |
| `remove_ads` | Non-consumable | $3.99 | Removes all Interstitial ads permanently |
| `starter_pack` | Non-consumable, one-time offer | $2.99 | 300 coins + remove_ads + exclusive mirror frame cosmetic (shown once, after Chapter 1 completion, at a psychologically appropriate "hooked but not yet paying" moment) |
| `cosmetic_pack_*` (future) | Consumable/Non-consumable | $0.99–$2.99 | Mirror/beam cosmetic skins, purely visual, zero gameplay impact |

**IAP-001:** No subscription model at launch (documented decision — subscriptions fit poorly with a session-based puzzle game and risk BIZ-006 churn-from-unfair-monetization goal).

---

# 54. Reward Systems

**REW-001 — Reward Feedback Loop:** Every reward grant (coins, stars, achievement) is accompanied by clear, satisfying but brief visual/audio/haptic feedback (≤ 1.5s), never a forced multi-second unskippable animation.

**REW-002 — Reward Transparency:** Players can always see exactly what a hint, purchase, or achievement will grant BEFORE committing (no loot-box-style randomized rewards anywhere in the product — documented as a hard exclusion, see §93).

---

# 55. Analytics Events

| Event | Trigger | Key Params |
|---|---|---|
| `level_start` | Level entered | `levelId`, `chapterId`, `attemptNumber` |
| `level_complete` | Win condition met | `levelId`, `starsEarned`, `timeSeconds`, `moveCount`, `hintTiersUsed` |
| `level_abandon` | Player exits mid-level | `levelId`, `timeSpentSeconds`, `mirrorsTouched` |
| `hint_requested` | Any hint tier requested | `levelId`, `tier`, `paymentMethod` (coins/ad) |
| `chapter_unlock` | New chapter unlocked | `chapterId` |
| `building_mode_session` | Building Mode entered/exited | `durationSeconds`, `objectsPlaced`, `roomsUsed` |
| `iap_purchase` | Successful purchase | `sku`, `priceUsd` |
| `ad_impression` | Ad shown | `adType`, `placement` |
| `ad_reward_granted` | Rewarded ad completed | `rewardType`, `amount` |
| `daily_reward_claimed` | Daily reward claimed | `dayInCycle`, `streakCount` |
| `app_open` / `session_start` | App foregrounded | `daysSinceInstall`, `sessionNumber` |
| `settings_changed` | Any setting toggled | `settingKey`, `newValue` |

**ANA-001:** All analytics collection complies with platform consent requirements (ATT prompt on iOS before any tracking-capable SDK initializes; a clear first-run privacy notice on both platforms).

---

# 56. Game Balance

**BAL-002 — Hint Economy Balance Target:** A player earning coins purely through normal play (no ad watching, no purchase) should be able to afford roughly 1 Tier-1 hint per 2 levels completed at 2-star average performance — ensuring hints feel accessible but not infinite/trivial.

**BAL-003 — Building Mode Unlock Pacing:** A player progressing through the main chapters at a normal pace should unlock their 2nd Building Mode room by roughly Chapter 4, and their 4th room by roughly Chapter 7, ensuring sandbox expansion feels tied to mastery without requiring IAP.

**BAL-004 — Balance Review Cadence:** Economy constants (coin values, IAP pricing, hint costs) are stored in a remotely-configurable balance table (Firebase Remote Config or equivalent) so they can be tuned post-launch without an app store resubmission — see §69/§85.

---

# 57. UI Screen List

*(Full detail for each screen — purpose, features, actions, navigation, data, states — is provided in the companion document "Application Screens & Navigation Flow" previously delivered. This section restates the canonical list for completeness of this master PRD; refer to that document for full per-screen specification.)*

Splash/Launch, Onboarding/Tutorial, Main Menu, Chapter Selection, Level Selection, Gameplay Screen, Level Complete, Level Failed/Retry (bonus-objective context only), Pause Menu, Hint System Overlay, Building Mode Hub, Building Mode Editor/Room View, Achievements, Statistics, Settings, Save & Continue/Save Slot Manager, Daily Challenge, Offline Progress Summary, Store/IAP, No Connection/Error.

---

# 58. Navigation Flow

*(Full ASCII navigation map provided in the companion "Application Screens & Navigation Flow" document; that document's §4.3 is incorporated here by reference as the authoritative navigation graph for this PRD.)*

---

# 59. Notifications

| ID | Notification | Trigger | Opt-in Required |
|---|---|---|---|
| NOT-001 | Daily reward available | 24h since last claim | Yes |
| NOT-002 | Streak about to break | Grace-day window closing | Yes |
| NOT-003 | New Daily Challenge available | New challenge published | Yes |
| NOT-004 | Win-back | 3+ days inactive, single gentle nudge, max 1 per week | Yes |
| NOT-005 | New content update | New chapter/season shipped | Yes |

**NOT-006:** All notifications are opt-in only (requested via platform permission prompt at a contextually appropriate moment — after first Daily Reward claim, not on first app launch), and every notification type is individually togglable in Settings. No notification uses manipulative/guilt-based copy (documented content-writing standard).

---

# 60. Settings

| Setting | Type | Default |
|---|---|---|
| Music Volume | Slider 0–100% | 70% |
| SFX Volume | Slider 0–100% | 100% |
| Haptics | Toggle | On |
| Language | Dropdown | Device locale (fallback English) |
| Notifications (per-type) | Toggles | All off until first opt-in prompt accepted |
| Assist Mode (larger hit-boxes/tolerance) | Toggle | Off |
| Angle Readout | Toggle | Off |
| Cloud Save Account Link | Action | Not linked |
| Reset Progress | Destructive Action (double confirmation) | — |
| Terms/Privacy/Credits | Links | — |

---

# 61. Audio Requirements

| ID | Requirement |
|---|---|
| AUD-001 | Ambient background music per chapter theme, looping seamlessly, low-key/non-intrusive to support long focus sessions |
| AUD-002 | Distinct SFX for: mirror rotation (subtle mechanical creak, intensity scales with rotation speed), beam-crystal contact (soft chime), crystal fully lit (rewarding resonant tone), level complete (short fanfare, ≤2s), hint reveal, button taps, coin gain |
| AUD-003 | All audio must be duck-able (music ducks under SFX) and fully mutable independently (music vs SFX vs haptics, per §60) |
| AUD-004 | Audio engine: use a Flutter audio package supporting low-latency SFX triggering (see §71) to keep audio-visual sync under 30ms for the beam-contact chime |

---

# 62. Animation Requirements

| ID | Requirement |
|---|---|
| ANI-001 | Mirror rotation is directly input-driven (1:1 with drag), no eased/delayed follow — precision control is paramount |
| ANI-002 | Beam appearance/disappearance (e.g., on level load) animates in with a brief "power-on" draw-on effect (≤400ms), not an instant snap, for polish |
| ANI-003 | Crystal charging state animates a smooth fill/pulse over the exact `HOLD_TIME` duration so players get accurate visual feedback of "how close" they are |
| ANI-004 | Screen transitions (menu-to-menu) use consistent, quick (200–300ms) shared-axis or fade transitions; never block input during transition beyond the transition's own duration |
| ANI-005 | Level Complete celebration animation capped at 2.5s before "skip/continue" becomes available, never fully blocking |

---

# 63. Visual Effects Requirements

| ID | Requirement |
|---|---|
| VFX-001 | Beam glow: layered semi-transparent stroke approximation (see REND-003), not real bloom post-processing (performance) |
| VFX-002 | Crystal lit-state: particle burst (lightweight, capped particle count ≤ 30 per crystal) on transition to `Lit` |
| VFX-003 | Dust motes/ambient particles in room background for atmosphere, capped and disabled automatically on Low performance tier (adaptive quality, see §75) |
| VFX-004 | Level Complete: confetti/light-burst effect, capped particle count, GPU-cheap (sprite batching) |

---

# 64. Art Direction

**ART-001 — Tone:** Grounded, warm, tactile realism — think handcrafted wood-and-brass optics instruments, attic workshops, observatories, greenhouses — NOT sci-fi neon, NOT cartoon-flat abstraction. This supports the "believable optical mechanics" mandate from the design brief.

**ART-002 — Palette Strategy:** Each chapter has a distinct but harmonious palette (e.g., Ch.1 "Workshop" = warm ambers/browns; Ch.2 "Observatory" = deep blues/silvers) with the beam's cyan-white color remaining a constant, high-contrast throughline across all themes for legibility.

**ART-003 — Mirror/Object Rendering:** Mirrors rendered with subtle material shading (brushed metal frame, glass highlight) to reinforce physicality — avoiding flat vector shapes that would undercut the "realistic mechanical hinge" narrative.

**ART-004 — UI Chrome:** Minimal, unobtrusive HUD during gameplay (objective text, pause/hint/reset icons only) to keep visual focus on the puzzle itself.

---

# 65. Asset Pipeline

**PIPE-001 — Format Standards:** Vector-sourced art (Figma/Illustrator) exported to optimized SVG-to-Flutter-compatible formats or pre-rasterized PNG sprite atlases at 1x/2x/3x density; texture atlases used for all in-scene sprites to minimize draw calls.

**PIPE-002 — Level Authoring Tool:** A companion internal level editor (web or Flutter-based) that outputs Level JSON (§66) directly, including built-in solvability validation (PDG-001) before export — this tool is itself a required deliverable for the content pipeline to scale to hundreds of levels (see §96).

**PIPE-003 — Audio Pipeline:** All SFX delivered as OGG/AAC, compressed, ≤ 100KB per short SFX clip; music tracks streamed rather than fully loaded into memory where package support allows.

---

# 66. Level JSON Structure

```json
{
  "levelId": "ch1_012",
  "chapterId": "ch1",
  "schemaVersion": 1,
  "roomBounds": { "width": 1080, "height": 1920 },
  "lightSources": [
    { "id": "ls1", "position": [120, 300], "direction": 90.0, "locked": true }
  ],
  "mirrors": [
    {
      "id": "m1",
      "hingePosition": [540, 700],
      "length": 160,
      "initialAngle": 45.0,
      "minAngle": 5.0,
      "maxAngle": 175.0,
      "snapIncrement": 0,
      "isLocked": false,
      "type": "standard"
    }
  ],
  "obstacles": [
    { "id": "o1", "polygon": [[300,300],[360,300],[360,900],[300,900]], "isDecorative": false }
  ],
  "targetCrystals": [
    { "id": "c1", "position": [900, 1400], "hitRadius": 40, "groupId": "g1" }
  ],
  "crystalGroups": [
    { "groupId": "g1", "requiredCount": 1 }
  ],
  "doorPortals": [],
  "intendedSolution": {
    "mirrorAngles": { "m1": 128.0 },
    "toleranceDegrees": 4.0
  },
  "starThresholds": {
    "threeStarMoveCount": 3,
    "threeStarTimeSeconds": 45
  },
  "metadata": {
    "designer": "string",
    "difficultyBand": "ch1",
    "newConceptsIntroduced": []
  }
}
```

---

# 67. Data Models

**Player Save Model (`PlayerSave`):**
```
PlayerSave {
  saveSchemaVersion: int
  playerId: String (local UUID)
  coins: int
  totalStars: int
  levelProgress: Map<levelId, LevelProgress>
  chapterUnlocks: Map<chapterId, bool> // derived/cache, see PROGSAVE-002
  achievements: Map<achievementId, AchievementState>
  buildingModeSaves: List<BuildingLayoutSave>
  settings: SettingsModel
  dailyRewardState: { lastClaimedDay: DateTime, streakCount: int }
  installTimestamp: DateTime
}

LevelProgress {
  levelId: String
  bestStars: int (0-3)
  bestMoveCount: int?
  bestTimeSeconds: double?
  hintTiersUsedEver: List<int>
  completedAt: DateTime?
  attemptCount: int
}

AchievementState {
  achievementId: String
  unlocked: bool
  unlockedAt: DateTime?
  progressCurrent: num
  progressTarget: num
}

BuildingLayoutSave {
  slotId: String
  roomSetId: String
  name: String
  objects: List<PlacedObject>
  lastModified: DateTime
}
```

---

# 68. API Requirements

Mirror Logic is offline-first; the following are the ONLY networked endpoints required, all optional/non-blocking to core play:

| Endpoint | Purpose | Backend |
|---|---|---|
| `GET /daily-challenge/current` | Fetch today's validated Daily Challenge level JSON | Firebase Functions / lightweight REST |
| `POST /cloud-save/sync` | Upload/merge player save (optional, opted-in) | Firebase/Supabase |
| `GET /remote-config` | Fetch tunable balance constants (§56 BAL-004) | Firebase Remote Config |
| `POST /analytics/event` | Batched analytics event upload | Firebase Analytics / equivalent |
| IAP validation | Server-side receipt verification | Google Play / Apple StoreKit server APIs, proxied via Cloud Functions |

**API-001:** All endpoints must fail silently/gracefully from the player's perspective (cached last-known state used; no blocking spinners on core gameplay paths).

---

# 69. Local Storage Requirements

**LS-STORE-001:** Primary local database: **Isar** or **Hive** (Flutter-native, fast, NoSQL, no native binary bridge overhead) for `PlayerSave` and all sub-models — chosen over `sqflite`/SQL for schema flexibility given frequent early-stage iteration on save shape, and superior read/write performance for this document-shaped data (see §71 for final package recommendation).

**LS-STORE-002:** Level JSON content bundled as app assets (not database-stored) for the 300+ handcrafted levels, loaded and parsed on-demand per level/chapter to keep memory footprint low; Building Mode and Daily Challenge data ARE stored in the local database since they are player/server-generated.

**LS-STORE-003:** Remote Config values cached locally with a fallback default baked into the app, so first-launch-offline scenarios still function correctly (NFR/OFF compliance).

---

# 70. Flutter Architecture

**ARCH-001 — State Management:** **Riverpod** (recommended over Bloc/Provider/GetX for this project) — chosen for compile-time safety, testability, and clean separation of gameplay simulation state from UI state, without the boilerplate overhead of Bloc for a project of this interaction density.

**ARCH-002 — Layered Architecture:**
```
presentation/   → Screens, widgets, view-models (Riverpod notifiers)
domain/         → Core game logic: BeamSimulator, ReflectionMath, LevelValidator, WinConditionEvaluator
data/           → Repositories: LevelRepository, SaveRepository, EconomyRepository, RemoteConfigRepository
infrastructure/ → Platform bindings: AdsService, IAPService, AnalyticsService, LocalStorageService, AudioService
```

**ARCH-003 — Rendering Strategy:** Gameplay canvas (beam, mirrors, crystals) rendered via a single `CustomPainter` driven by a `GameplayController` (domain layer) that holds the authoritative simulation state — UI widgets (HUD, buttons) remain standard Flutter widgets layered on top via `Stack`, keeping the performance-critical path isolated from the widget tree's rebuild cost (see §76).

**ARCH-004 — Domain Logic is Engine-Agnostic:** `BeamSimulator`/`ReflectionMath` are written as pure Dart (no Flutter/UI dependencies) so they are independently unit-testable and, if ever needed, portable to a server-side validator (used by PIPE-002's level authoring tool and the Daily Challenge solvability pre-check in API-001).

---


# 71. Recommended Packages

| Purpose | Package | Rationale |
|---|---|---|
| State management | `flutter_riverpod` | See ARCH-001 |
| Local database | `isar` (or `hive` + `hive_flutter`) | Fast, schema-flexible, no native SQL bridge overhead |
| Routing | `go_router` | Declarative, deep-link-ready, matches Navigator 2.0 recommendation from screen-flow doc |
| Localization | `flutter_localizations` + `intl` + `slang` or `easy_localization` | ARB-based, type-safe string access |
| Audio | `audioplayers` or `just_audio` | Low-latency SFX + background music streaming support |
| Haptics | `flutter/services.dart HapticFeedback` (built-in) or `vibration` for finer control | Minimal dependency footprint |
| Ads | `google_mobile_ads` (AdMob) | Industry standard, supports rewarded + interstitial |
| IAP | `in_app_purchase` (official Flutter plugin) | Cross-platform official support |
| Analytics | `firebase_analytics` + custom event wrapper | Free tier sufficient at launch scale |
| Remote Config | `firebase_remote_config` | See BAL-004 |
| Cloud save (optional) | `cloud_firestore` or Supabase SDK | Lightweight document sync |
| Animations | `flutter_animate` or built-in `AnimationController` | For ANI-002 through ANI-005 |
| Testing | `flutter_test`, `mocktail`, `golden_toolkit` | Unit, widget, and golden-image regression testing |
| Performance monitoring | `firebase_performance` | Frame-time and cold-start tracking in production |

**PKG-001 — Explicit Exclusion:** No full 2D physics/game engine (e.g., Flame with Forge2D/box2d) is required for the core beam mechanic per PHY-R-001 — introducing a full rigid-body physics engine would add unnecessary complexity and performance risk for a purely kinematic raycast system. `flame` MAY optionally be adopted purely as a rendering/game-loop convenience layer (P2 evaluation), not for physics.

---

# 72. Folder Structure

```
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme.dart
  core/
    constants/
    utils/
    errors/
  domain/
    beam/
      beam_simulator.dart
      reflection_math.dart
      raycast_utils.dart
    level/
      level_model.dart
      level_validator.dart
      win_condition_evaluator.dart
    economy/
      economy_model.dart
    building_mode/
      building_layout_model.dart
      placement_rules.dart
  data/
    repositories/
      level_repository.dart
      save_repository.dart
      economy_repository.dart
      remote_config_repository.dart
    models/ (data-transfer objects, JSON (de)serialization)
  infrastructure/
    ads/ads_service.dart
    iap/iap_service.dart
    analytics/analytics_service.dart
    storage/local_storage_service.dart
    audio/audio_service.dart
    notifications/notifications_service.dart
  presentation/
    screens/
      splash/
      onboarding/
      main_menu/
      chapter_selection/
      level_selection/
      gameplay/
        gameplay_screen.dart
        gameplay_painter.dart
        widgets/ (hud, pause_menu, hint_overlay)
      level_complete/
      building_mode/
        building_hub_screen.dart
        building_editor_screen.dart
      achievements/
      statistics/
      settings/
      store/
    widgets/ (shared components)
    theme/
  l10n/ (ARB files)
assets/
  levels/ (per-chapter JSON files)
  images/
  audio/
  fonts/
test/
  domain/
  data/
  widget/
  golden/
```

---

# 73. Coding Standards

| ID | Standard |
|---|---|
| CODE-001 | Follow official `flutter_lints` / `very_good_analysis` ruleset; zero-warning CI gate |
| CODE-002 | All public domain-layer classes/functions fully documented with `///` doc comments including units (degrees vs radians must be explicit in every function signature, e.g., `rotateMirrorDegrees(double angleDegrees)`) |
| CODE-003 | No business logic in widget `build()` methods — widgets read from Riverpod providers only; all logic lives in domain/data layers (testability requirement) |
| CODE-004 | Immutable data models (`freezed` package recommended) for all save/level models to prevent accidental mutation bugs in shared state |
| CODE-005 | Consistent null-safety discipline — no `!` non-null assertions in domain logic without an accompanying explanatory comment justifying invariant safety |
| CODE-006 | Feature branches + PR review required for any change to `domain/beam/` (physics core) given its correctness sensitivity — mandatory unit test coverage for any PR touching reflection math |

---

# 74. Performance Optimization

| ID | Technique |
|---|---|
| PERFOPT-001 | Object pooling for beam segment lists (reuse across frames, avoid per-frame `List` allocation) — see PERF-001 |
| PERFOPT-002 | Spatial partitioning (simple grid or BVH) for raycast collision queries once object counts scale in Building Mode (`MAX_BUILDING_OBJECTS = 60`) to avoid O(n) per-segment brute force at scale |
| PERFOPT-003 | `RepaintBoundary` isolation around the gameplay `CustomPainter` so HUD widget rebuilds never trigger a full canvas repaint |
| PERFOPT-004 | Sprite atlasing to minimize texture binds/draw calls (§65 PIPE-001) |
| PERFOPT-005 | Lazy-load chapter assets (only current + adjacent chapter's assets resident in memory) rather than bundling all 300+ levels' assets into memory at once |

---

# 75. Memory Optimization

| ID | Technique |
|---|---|
| MEM-001 | Adaptive VFX quality: automatically detect Low-tier devices (via a simple frame-time calibration check on first launch) and disable ambient particles (VFX-003), reduce glow layer count (VFX-001) |
| MEM-002 | Dispose all `AnimationController`, `AudioPlayer`, and stream subscriptions on screen disposal — enforced via a lint rule / code review checklist |
| MEM-003 | Image cache size capped explicitly (`PaintingBinding.instance.imageCache.maximumSizeBytes`) to prevent unbounded growth across long Building Mode sessions with many asset swaps |
| MEM-004 | Level JSON parsed and discarded (not cached indefinitely) once a level is exited, except for the currently active + immediately-previous level (back-navigation smoothness) |

---

# 76. Rendering Strategy

**REND-STRAT-001:** Single `CustomPainter` (`GameplayPainter`) owns rendering of: room background, obstacles, mirrors, light source, beam segments, crystals, and their state-driven visual effects — all driven by an immutable `GameplaySnapshot` value object produced once per frame by the domain layer.

**REND-STRAT-002:** HUD (objective text, pause/hint/reset buttons, star progress) is implemented as ordinary Flutter widgets in a `Stack` above the painter, updating independently via their own Riverpod providers, so HUD state changes never force a beam-canvas repaint and vice versa (see PERFOPT-003).

**REND-STRAT-003:** Building Mode uses the same `GameplayPainter` core (beam rendering is identical logic) extended with an editing-overlay painter layer for grid snapping/placement previews, ensuring beam-rendering code is never duplicated between Standard Levels and Building Mode (DRY, and reduces physics-bug surface area to one implementation).

---

# 77. Physics Engine Recommendation

**PHYSREC-001:** **No third-party rigid-body physics engine is required or recommended** for the core beam mechanic. The entire simulation is a custom, lightweight, deterministic raycast-and-reflect system (§26) implemented in pure Dart within `domain/beam/`. This is a deliberate architectural recommendation: adopting Box2D/Forge2D (via Flame) would add unnecessary complexity, non-determinism risk, and performance overhead for a system that has no need for gravity, velocity, mass, or collision response beyond simple ray-segment intersection tests.

**PHYSREC-002:** If Building Mode's free object placement later requires overlap prevention or drag-and-drop physical "settling" behavior (a nice-to-have polish item), a minimal custom AABB/OBB overlap-check utility is sufficient — still no full physics engine needed.

---

# 78. Testing Strategy

| Layer | Approach | Tooling |
|---|---|---|
| Unit — Domain | 100% coverage target on `ReflectionMath`, `BeamSimulator`, `WinConditionEvaluator`, `LevelValidator` given correctness sensitivity | `flutter_test`, table-driven test cases covering axis-aligned, angled, multi-bounce, edge-of-mirror-length, and max-bounce-exceeded scenarios |
| Unit — Data/Repositories | Save/load round-trip integrity, schema migration correctness | `flutter_test`, `mocktail` for storage mocking |
| Widget | Screen rendering correctness, navigation flow correctness per §58 | `flutter_test`, `golden_toolkit` for visual regression |
| Integration | Full level-solve flow (load level → simulate drag inputs → assert win state) for a representative sample across all chapters | `integration_test` package |
| Level Content QA | Automated solvability validation for every shipped level (PDG-001) run in CI on every content PR | Custom `LevelValidator` CLI tool (domain layer, engine-agnostic per ARCH-004) |
| Performance | Frame-time profiling on reference device tiers before each release | Flutter DevTools, `firebase_performance` production monitoring |
| Manual Playtest | Every level passes 2-tester blind playtest (§35 PDG-005) before ship | Internal playtest tracker spreadsheet/tool |

---

# 79. QA Checklist

- [ ] Every level loads without error and renders all objects at correct positions
- [ ] Every level's `intendedSolution` is verified solvable by `LevelValidator` within tolerance
- [ ] No level triggers `MAX_BOUNCES` exceeded under its intended solution or any reasonable exploratory input
- [ ] Win condition triggers correctly and does not false-trigger on beam "flicker" during dragging (RULE-004 hold-time verified)
- [ ] All mirrors respect `minAngle`/`maxAngle` clamps under all input speeds (including fast flicks)
- [ ] Locked mirrors are visually distinguishable without color as the only cue (ACC-001)
- [ ] Hint system delivers correct tiered information matching `intendedSolution` data
- [ ] Save/load round-trip preserves all progress fields exactly across app restart
- [ ] Offline mode: full chapter playthrough possible with airplane mode enabled
- [ ] All strings pass through localization system (no hardcoded English visible when device locale changed)
- [ ] Accessibility: full level completable using only single-finger drag, with Assist Mode on and off
- [ ] Ads: rewarded ad flow completes and grants correct reward; interstitial respects frequency cap and `remove_ads` purchase
- [ ] IAP: purchase flow completes, receipt validated server-side, content granted exactly once (no duplicate-grant on restore)
- [ ] Performance: sustained 60fps on Mid tier reference device across a full chapter playthrough profiling session
- [ ] Crash-free: no crashes across a scripted 30-minute soak test covering all screens

---

# 80. Acceptance Criteria

Acceptance criteria are defined per functional requirement using Given/When/Then format. Representative examples (full set to be maintained in backlog tool, one per FR/MIR/etc. ID):

**FR-002 (Mirror Rotation):**
- Given a level with an unlocked mirror at `minAngle=5°, maxAngle=175°`
- When the player drags from the mirror's handle to a screen position corresponding to a raw angle of 200°
- Then the mirror's rendered angle clamps to 175° and does not exceed it

**FR-003 (Win Detection):**
- Given a level requiring 1 crystal lit
- When the beam continuously intersects the crystal for ≥0.4s
- Then the level transitions to `Solved` state and the Level Complete screen is shown within 1 additional second (post celebration animation)

**HINT-004 (No Full Auto-Solve):**
- Given a level with 3 mirrors
- When the player requests Tier 3 hints
- Then at most one mirror is auto-solved per Tier 3 request, requiring 3 separate requests (and costs) to fully solve via hints

---

# 81. Edge Cases

| ID | Edge Case | Required Handling |
|---|---|---|
| EDGE-001 | Beam exits the room bounds without hitting anything | Rendered as a beam segment extending to a `FAR_DISTANCE` clipped at room-bounds visual edge, fading out; no crash, no infinite segment |
| EDGE-002 | Two mirrors perfectly parallel, reflecting beam back and forth | `MAX_BOUNCES` guard terminates simulation gracefully (§PHYS-004); this configuration must never appear in an authored `intendedSolution` (caught by LevelValidator) |
| EDGE-003 | Beam strikes exactly at a mirror's edge (boundary between reflective surface and empty mount) | Deterministic tie-break: any hit within `EPSILON` of the mirror's endpoint counts as a miss (absorbed), consistently, to avoid flickering between hit/miss states during micro-adjustments |
| EDGE-004 | Player rapidly toggles a mirror in/out of a crystal's hold-time window | `HOLD_TIME` timer resets to 0 immediately on any contact break, per RULE-004, preventing exploit of partial-credit solving |
| EDGE-005 | App backgrounded mid-drag gesture | Gesture is cancelled cleanly on `AppLifecycleState.paused`; mirror retains its last valid angle, no stuck-drag state on resume |
| EDGE-006 | Player has zero coins and no ad available (offline, no fill) | Tier 0 hint (free, text-only) remains available; Tier 1+ hints show a clear "unavailable offline" message, never a silent failure |
| EDGE-007 | Save data schema version mismatch after app update | Migration routine runs (SAVE-003); if migration path doesn't exist for a version jump, fallback to best-effort field-mapping with a non-destructive backup retained |
| EDGE-008 | Building Mode room with beam looping through a `DoorPortal` back into its own source room creating a cycle | Same `MAX_BOUNCES` guard applies globally across room transitions, not reset per-room, preventing infinite cross-room loops |
| EDGE-009 | Device rotated to landscape | App locks to portrait per product requirement (PROD spec); rotation lock enforced at platform manifest level, no landscape layout needs to be designed |

---

# 82. Risk Analysis

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Content pipeline bottleneck (hand-authoring 300+ verified-solvable levels) | High | High | Invest early in Level Authoring Tool with built-in solvability validation (PIPE-002) to reduce iteration cost |
| Physics edge cases (parallel mirrors, tangent hits) causing visual glitches | Medium | Medium | Comprehensive table-driven unit test suite (§78) covering all documented edge cases (§81) before content scale-up |
| Monetization underperformance if hint economy too generous | Medium | Medium | Remote-configurable balance constants (BAL-004) allow live tuning without app update |
| Performance degradation on low-end devices in Building Mode at high object counts | Medium | Medium | Enforced `MAX_BUILDING_OBJECTS` cap + adaptive VFX quality (MEM-001) + spatial partitioning (PERFOPT-002) |
| Feature creep diluting the "elegant, respectful" positioning | Medium | High | §93 (Features That Should Never Be Added) treated as a binding design constraint, reviewed at every roadmap planning session |

---

# 83. Technical Risks

| ID | Risk | Mitigation |
|---|---|---|
| TR-001 | Dart GC pauses causing frame drops during intensive raycast frames | Object pooling (PERFOPT-001), profiling gate before each release (§78) |
| TR-002 | Riverpod provider rebuild storms if gameplay state granularity is too coarse | Split providers by concern (mirror angles, HUD state, beam snapshot) rather than one monolithic gameplay provider |
| TR-003 | IAP/Ads SDK platform policy changes (App Tracking Transparency, Play Billing version deprecation) | Keep SDK dependencies on actively-maintained official packages; quarterly dependency audit |
| TR-004 | Save data corruption in the field | Rolling backup copy (SAVE-004), checksum validation (SEC-001) |

---

# 84. Product Risks

| ID | Risk | Mitigation |
|---|---|---|
| PR-001 | Market perceives the game as "just another match-3-adjacent puzzle" due to poor initial screenshots/store listing | Store creative must foreground the real-time beam mechanic specifically (unique visual hook), not generic puzzle-grid imagery |
| PR-002 | Building Mode is underused if not surfaced early/clearly enough | Progression unlock at Chapter 2 (PROG-004) is deliberately early; Main Menu surfaces it as a first-class entry point, not buried in a submenu |
| PR-003 | Difficulty curve too steep causes early churn | Continuous playtesting against §29 target solve times; analytics on `level_abandon` events monitored closely post-launch, per-level, with a response SLA to patch outlier levels via remote content update |
| PR-004 | Perceived unfair monetization damages store rating (impacts BIZ-006) | All monetization reviewed against MON-001 "never blocks progression" principle before shipping any new monetized feature |

---

# 85. Future Roadmap

| Phase | Timeframe (indicative) | Content |
|---|---|---|
| Launch (v1.0) | Month 0 | Chapters 1–6 (260 levels), Building Mode (4 starter rooms), core economy, Achievements, Statistics, Settings, Ads/IAP |
| v1.1 | Month 1–2 | Bug-fix/balance pass based on live analytics (PR-003 response), first Achievement expansion |
| v1.2 | Month 2–3 | Chapter 7 (60 new levels), Daily Challenge feature launch |
| v1.3 | Month 3–4 | Building Mode sharing/export (BUILD-007), community puzzle feature |
| v1.4 | Month 4–6 | Seasonal themed chapter (limited-time), cosmetic mirror skins |
| v2.0 | Month 6–9 | Rotatable Light Source levels (LS-003), Beam Color Filters (§34), expanded Building Mode object palette |
| v2.x+ | Month 9–12+ | Weekly Community Puzzle, potential async co-op Building Mode, platform expansion evaluation (e.g., web/desktop port of Building Mode as a marketing tool) |

---

# 86. Version Planning

| Version | Scope Gate |
|---|---|
| v1.0 | All P0 requirements across every section of this document; Chapters 1–6 fully content-complete and QA-passed per §79 |
| v1.1–v1.3 | P1 requirements rolled out incrementally; live-ops content cadence established (BIZ-004 target: 40–60 levels/month sustainable pipeline) |
| v2.0 | P2 requirements evaluated based on v1.x retention/monetization data; no P2/P3 feature ships without post-launch data supporting its ROI |

---

# 87. Release Plan

1. **Alpha (Internal):** Chapters 1–2 playable, core loop + save system + hint system functional, no monetization/ads integrated yet. Goal: validate core fun and physics correctness.
2. **Closed Beta:** Chapters 1–4, Building Mode (1 room), full economy + ads/IAP integrated in sandbox/test mode, small external tester group (50–200 users) for retention/difficulty-curve signal.
3. **Soft Launch:** Full v1.0 content in 1–2 smaller test markets, live monetization active, analytics fully instrumented, 2–4 week observation window against BIZ-001/002 targets before global launch.
4. **Global Launch:** Full rollout across target markets (§6) with store creative optimized per soft-launch learnings (PR-001 mitigation).
5. **Post-Launch Cadence:** Follow §85 roadmap; maintain the 40–60 levels/month content pipeline (§96) starting immediately post-launch to avoid a content-drought retention cliff around week 3–4.

---

# 88. Appendices

**Appendix A:** Level JSON Schema (full, versioned) — maintained as a living document alongside `domain/level/level_model.dart`; §66 in this PRD is the v1 baseline snapshot.

**Appendix B:** Full Achievement List — maintained in a separate content spreadsheet (§48 shows representative sample only; full list target is 40–60 achievements at launch).

**Appendix C:** Full Economy Balance Table — maintained in Remote Config (BAL-004); §45–§47 constants in this document are v1.0 launch defaults, not immutable.

**Appendix D:** Localization String Glossary — maintained in `l10n/` ARB source files.

---

# 89. Glossary

| Term | Definition |
|---|---|
| Beam | The continuous light ray simulated from the Light Source through any number of mirror reflections to a termination point |
| Bounce | A single reflection event where the beam changes direction off a mirror surface |
| Hinge | The fixed pivot point around which a mirror rotates |
| Hold Time | The continuous duration a beam must remain on a target crystal for a solve to register (§RULE-004) |
| Tolerance Band | The angular margin of error around an "ideal" solution angle that still counts as correct (§PDG-003) |
| Vault Level | A bonus level unlocked via star-threshold mastery rather than sequential completion |
| Building Mode | The free-form multi-room sandbox mode with no win/fail condition |
| DoorPortal | The Building Mode object connecting beam continuity between two adjacent rooms |
| Blueprint Points | The Building Mode-contextual label for the Coins currency when spent on room/object unlocks (§45, documented simplification) |

---

# 90. Open Questions

| # | Question | Owner | Status |
|---|---|---|---|
| 1 | Should Daily Challenges support difficulty selection (easy/hard variant per day) or a single fixed challenge? | Product | Open — recommend single fixed challenge for v1.2 simplicity, revisit post-launch |
| 2 | Should cloud save be mandatory-prompted at first launch or fully opt-in/hidden until Settings is visited? | Product/UX | Recommend fully opt-in, discovered via Settings only, to minimize onboarding friction (PROD-001) |
| 3 | Exact starter chapter count for launch (6 vs. 8) given content pipeline velocity risk (§82) | Production | Open — depends on Level Authoring Tool (PIPE-002) delivery timeline |
| 4 | Should Building Mode sharing (BUILD-007) require moderation before a shared layout is visible to others? | Trust & Safety | Open — likely yes, lightweight automated + report-based moderation, needs scoping |
| 5 | Is a companion web version of Building Mode (marketing/acquisition tool, §85 v2.x) worth the Flutter-web engineering investment? | Product/Eng leadership | Open — revisit after v1.x retention data |

---

# 91. Design Decisions

This section consolidates the key documented assumptions and deliberate simplifications made throughout this PRD, for transparency and future design-review reference:

1. **No refraction/glass physics** — one-way mirrors modeled as binary reflective/transparent (§MIR-006).
2. **No lives/energy system anywhere in the product** — standard levels have no fail state (§16).
3. **No loot boxes / randomized rewards** — all rewards are transparent and predictable (§REW-002).
4. **No subscription monetization model at launch** (§IAP-001).
5. **Building Mode's "Blueprint Points" are a contextual relabeling of Coins**, not a separate currency, to reduce economy complexity (§45).
6. **No third-party rigid-body physics engine** — beam simulation is a custom deterministic raycast system (§PHYSREC-001).
7. **Crystals terminate the beam** (not pass-through), even though real light could theoretically continue through a translucent crystal — chosen for puzzle legibility (§CRY-003).
8. **Portrait-only** — no landscape mode investment (§EDGE-009).
9. **Chapter progression gates at 80% completion, not 100%**, to reduce single-hard-level frustration (§PROG-001).

---

# 92. Professional Recommendations

As Principal PM/Design Director on this project, the following recommendations are made beyond the explicit brief, based on genre and market experience:

1. **Invest in the Level Authoring Tool (PIPE-002) before scaling content production.** This is the single highest-leverage infrastructure investment — it directly de-risks BIZ-004 (content pipeline sustainability) and PDG-001 (solvability guarantees).
2. **Treat Building Mode as the primary marketing asset, not a secondary feature.** Screen-recorded, satisfying multi-room beam chains are highly shareable (TikTok/Instagram Reels potential) — plan store creative and social content strategy around it from day one.
3. **Resist the temptation to add a lives/energy system even under monetization pressure post-launch.** This is the single most common way genre-appropriate puzzle games erode goodwill; the "no fail state" design is a genuine differentiator worth defending (see §93).
4. **Prioritize the STEM/education-adjacent organic marketing angle** ("real optical physics, not fake game logic") — this is a legitimate, underused hook for the target demographic and costs nothing to message.
5. **Establish the Remote Config balance layer (BAL-004) before launch, not after** — retrofitting live-tunable economy values post-launch is significantly more expensive than building it in from v1.0.

---

# 93. Features That Should Never Be Added

This section is intentionally binding and should be treated as a design constraint requiring explicit executive sign-off to override:

- **Lives/energy systems** that block play until a timer expires or currency is spent.
- **Randomized loot boxes** or gacha-style reward mechanics of any kind.
- **Pay-to-skip-difficulty** mechanics that let currency substitute for solving a puzzle beyond the existing tiered Hint System.
- **Forced/unskippable ads** interrupting core gameplay (mid-level).
- **Banner ads** cluttering the gameplay or menu UI (contradicts premium-feel art direction, §64).
- **Fantasy/arcade mirror behavior** (mirrors that flip, teleport, detach, or violate real reflection physics) — this would undermine the entire "grounded realism" pillar of the product.
- **Aggressive re-engagement dark patterns** (guilt-tripping streak-loss copy, fake urgency countdown timers on non-time-limited content).
- **Full-auto-solve hints** that trivialize a puzzle in a single tap (§HINT-004).
- **Landscape mode support** — explicitly out of scope, would fragment layout QA effort for negligible player benefit given the product's portrait-first design.
- **PvP or competitive timed leaderboarderboard-primary modes** that would shift the game's core promise from calm cerebral solving to reflex/competition (a Weekly Community Puzzle with an optional leaderboard, §34, is acceptable as a secondary, opt-in mode — a core competitive shift is not).

---

# 94. Possible Future DLC

| Concept | Description |
|---|---|
| Seasonal Chapter Packs | Themed 40–60 level packs (e.g., "Winter Observatory") tied to real-world seasons, sold as optional one-time IAP or included free with ad-supported unlock, TBD by v1.x monetization data |
| Cosmetic Mirror/Beam Skin Packs | Pure-visual customization bundles, zero gameplay impact (REW principle-compliant) |
| "Master Architect" Building Mode Expansion Pack | Additional room types, object palette (colored filters, decorative elements) for Building Mode power users (Persona: Builder Ben) |
| Physical/Merch Tie-in (long-term, speculative) | Only if the IP achieves meaningful brand recognition — out of scope for this PRD's engineering planning |

---

# 95. Scalability Plan

**SCALE-001 — Content Scalability:** The Level Authoring Tool (PIPE-002) + Level JSON schema (§66) + automated `LevelValidator` (§78) together form a pipeline capable of sustaining 40–60 new levels/month post-launch (BIZ-004) without proportionally scaling engineering headcount, since content authoring is decoupled from app code changes (levels ship as data, potentially via over-the-air asset updates rather than app store resubmission for minor content drops — recommend evaluating Flutter's asset-delta update feasibility or a lightweight CDN-hosted level-pack system for this purpose).

**SCALE-002 — Backend Scalability:** All backend touchpoints (§68) are read-heavy, cache-friendly, and low-write-volume (no real-time multiplayer state), meaning a serverless architecture (Firebase Functions/Firestore or Supabase) comfortably scales to hundreds of thousands of DAU without dedicated infrastructure engineering investment at this stage.

**SCALE-003 — Team Scalability:** The layered architecture (§70 ARCH-002) allows content designers, UI engineers, and physics/domain engineers to work in parallel with minimal merge conflict surface, since level content, presentation, and domain logic are cleanly separated.

---

# 96. 1000+ Level Content Pipeline

To scale from the launch target of ~300 levels toward a long-term library of 1000+ levels (a realistic 2–3 year horizon for a successful live-ops puzzle game), the following pipeline investments are recommended:

1. **Level Authoring Tool v2:** Add procedural "scaffold generation" (NOT full procedural level generation for player-facing content, per §28 no-randomness principle, but a designer-facing tool that generates candidate room/mirror layouts for a human designer to curate, edit, and finalize) — this accelerates human-authored content velocity without compromising the hand-crafted-feel requirement.
2. **Concept Library System:** Maintain a tagged library of "puzzle concepts" (each documented with its teaching purpose, difficulty weight, and example levels) so new designers can compose fresh levels from proven concept combinations rather than inventing from scratch every time — directly supports BAL-001's escalation discipline at scale.
3. **Community-Sourced Building Mode Layouts as a Curation Funnel:** Once BUILD-007 (sharing) ships, the best community-created layouts can be identified (via engagement metrics) and adapted/polished by the internal design team into official chapter content — a proven pattern in successful sandbox-adjacent puzzle games.
4. **Automated Regression Suite Scaling:** As level count grows, the `LevelValidator` CI suite (§78) must remain fast enough to run on every content PR — recommend parallelized validation and a nightly full-library re-validation job to catch any physics-engine-change regressions across the entire back catalog.

---

# 97. Maintainability Strategy

| ID | Strategy |
|---|---|
| MAINT-001 | Domain logic (`domain/beam/`) treated as a stability-critical module with the highest test coverage and most conservative change-review process (CODE-006) in the codebase, since it underpins every level ever shipped |
| MAINT-002 | Level content is versioned data, not code — content updates should never require a full app binary review cycle where platform policy allows (SCALE-001) |
| MAINT-003 | Remote Config for all tunable balance values (BAL-004) reduces the need for emergency hotfix app releases when economy tuning is needed |
| MAINT-004 | Quarterly dependency audit (TR-003) to stay current with Flutter SDK, AdMob, and IAP plugin versions, avoiding technical-debt accumulation and platform policy compliance risk |
| MAINT-005 | Documentation-as-code: this PRD's requirement IDs are referenced directly in code comments and PR descriptions where relevant, keeping design intent traceable from spec to implementation over the product's lifetime |

---

# 98. Code Architecture Guidelines

Reiterating and consolidating the architectural mandates from §70–77 for engineering onboarding clarity:

1. Domain logic is pure Dart, framework-agnostic, and 100%-unit-testable in isolation from Flutter widgets.
2. UI never contains gameplay logic; UI reads immutable state snapshots from Riverpod providers and dispatches intents (e.g., `onMirrorDragged(mirrorId, newAngle)`) back into the domain layer.
3. Rendering is centralized in a single `CustomPainter` per gameplay context (Standard Level and Building Mode share the same painter core, per REND-STRAT-003).
4. No physics engine dependency; the beam simulator is bespoke, deterministic, and fully specified in §26/§77.
5. All numeric game-balance constants are sourced from Remote Config with safe bundled defaults, never hardcoded magic numbers scattered through the codebase.
6. Every new mirror/object type added in future content updates must be modeled as a data-driven extension of the existing `Mirror`/object schema (§66), not a bespoke one-off class, to preserve the single-source-of-truth rendering/physics pipeline.

---

# 99. Developer Notes

- Start implementation with `domain/beam/reflection_math.dart` and its full unit test suite before any UI work — this is the technical heart of the product and de-risks the entire project earliest.
- Build a minimal internal "level playground" screen very early (even before menus exist) that loads a raw Level JSON file and lets a developer drag mirrors — this becomes both a development tool and, eventually, the foundation of the real Gameplay Screen.
- The Level Validator (used for both QA and, later, the Level Authoring Tool) should be built as a standalone, importable Dart library from day one, not bolted on later — it will be reused by at minimum three consumers: CI content validation, the internal authoring tool, and (eventually) the Daily Challenge server-side pre-check.
- Treat §93 ("Features That Should Never Be Added") as a living checklist to reference during any future feature-request triage, especially under monetization pressure.
- When in doubt on any ambiguous mechanic not covered explicitly in this document, default to the design philosophy stated in §2 (Vision) and §28 (Level Design Philosophy): *does this respect the player's intelligence and time?*

---

# 100. Final Product Summary

Mirror Logic is a physics-grounded, real-time optical puzzle game for Flutter/mobile, built around one elegant, honest mechanic: rotate a mirror, watch a beam of light obey the real law of reflection, and think your way to the answer. Every system in this document — from the deterministic raycast engine, to the no-fail-state puzzle philosophy, to the transparent tiered hint system, to the sandbox Building Mode, to the deliberately restrained monetization model — is designed in service of a single coherent product identity: **a puzzle game that respects the player's intelligence.**

This document defines the complete v1.0 scope at implementation-ready detail, along with a scalable roadmap for 1000+ levels of long-term content, a monetization model that supports the business without compromising the design's integrity, and explicit, binding constraints (§93) protecting the product's identity against common mobile-game anti-patterns. It is intended to be handed directly to engineering (including AI coding agents such as Cursor AI) as the authoritative source of truth for building Mirror Logic from empty repository to global launch.

**End of Document.**
