# NewbieNudge 0.4.1: Paddle editor

Date: 2026-11-23. Status: draft, for approval.

## Why

The developer plays WoW Forever on a Steam Deck. The Deck has four back
paddles (L4, R4, L5, R5) that Forever's own controller interface never uses.
They want those paddles to do useful things: open a window (bags, character),
cast a spell directly, or act as an extra layer of abilities, without giving up
anything the game's controller bars already do.

An earlier attempt (0.4.0 and the first 0.4.1 builds) changed the game's hidden
controller settings (`GamePadEmulate*` and similar). That broke the game's
controller interface: it blamed NewbieNudge for `SetPreferredGamepadInteractTarget`,
`UseAction` and others, and forced the player to turn the addon off. The
replacement for that is this editor. The `/nudge pad` command and the read-only
list of pad assignments on the Controller page go away.

## What was learned on the live client (2026-11-23)

- Forever's controller bars are run by the game's own Lua (`GamepadMainActionBarFrame`,
  `GamepadActionBarBindingUtil`, `C_GamepadUI`). No pad button has an ordinary
  key binding (`GetBindingAction("PAD1")` and every modifier combination are empty).
  An addon cannot re-route RT or the face buttons by changing settings.
- With Steam Input, the paddles reach the game only as whatever Steam maps them
  to. With Steam's default layout they copy A/B/X/Y and the game cannot tell them
  apart; mapped to keyboard keys (F9 to F12 in the test) they arrive as those keys.
  Without Steam Input the client knows them as `PADPADDLE1` to `PADPADDLE4`.
- Throwaway test addon (NNPaddleSpike), confirmed in game:
  - `SetOverrideBinding(owner, true, "F10", ...)` and
    `SetOverrideBindingClick(owner, true, "F10", "<button>")` work for a paddle key.
  - A `SecureActionButtonTemplate, SecureHandlerBaseTemplate` button, clicked by
    the paddle with `RegisterForClicks("AnyDown", "AnyUp")`, runs a wrapped
    `OnClick` snippet in combat: on down `self:SetBindingClick(true, "PAD1", "<spell button>")`,
    on up `self:ClearBindings()`. Holding the paddle and pressing A cast
    Rejuvenation, in and out of combat, with no blocked action.
- The game refuses binding changes from addons in combat (`SetOverrideBinding`
  is protected), but the secure snippet above is allowed.

## Goals

1. Up to four paddles, each learned by pressing it ("Learn", then press).
   Whatever the press arrives as (keyboard key or pad button) is stored.
2. Each paddle does one of:
   - **Command:** any command in the game's key bindings list (open bags,
     character, map, spellbook, mount, target nearest enemy, autorun...).
   - **Spell**, **item** or **macro**, cast or used directly.
   - **Layer:** while held, A, B, X, Y and the four d-pad directions do eight
     extra actions instead (each one a command, spell, item or macro). Releasing
     the paddle gives those buttons back to the game.
3. Works in combat once set up. Editing only out of combat.
4. Never touches the game's controller settings or its controller bars.

## Non-goals

- Replacing or changing the game's controller bars, RT/LT behaviour, or any
  other button than the learned paddles (and, only while a layer paddle is held,
  the eight layer buttons).
- Tap versus hold on one paddle: the restricted environment has no timer.
- Different paddle actions while LT or RT is held: how the game's layers are
  implemented is unknown. Possible later, after a test.
- Configuring Steam Input. The window tells the player how; it can't do it.

## Anti-goals (a failure even if it works)

- Any return of the controller-interface error. Nothing in this feature may
  write a CVar, hook a Blizzard gamepad frame, or run from Blizzard's Settings
  panel.
- A paddle that stays bound to something after NewbieNudge is turned off or the
  paddle is cleared.

## Approaches considered

1. **NewbieNudge's own secure buttons (chosen).** One secure button per paddle and
   per layer slot, attributes set from the saved choice, paddle keys bound with
   override bindings. Full control, works for commands, spells, items, macros and
   layers. Cost: the slots (icon, drag and drop) are NewbieNudge's own code.
2. **Spare action bar slots** (GamepadExtraButtons' approach): paddles press slots on
   keyboard bars the controller interface hides. Cooldowns and drag and drop for
   free, but it uses slots other addons or the keyboard setup may need, and a
   layer is awkward. Rejected.
3. **Macros only.** NewbieNudge writes one macro per paddle. Simplest, but uses
   macro slots and is clumsy for commands and spells. Rejected.

The developer picked 1.

## Design

### Where it lives

- New file `NewbieNudge/Paddles.lua` (logic and bindings) and
  `NewbieNudge/PaddlesWindow.lua` (the editor window), added to the TOC.
- Saved per character in `NewbieNudgeDB.paddles` (spells differ per class):
  ```lua
  paddles = {
    enabled = true,
    [1] = { key = "F9",  action = { kind = "command", value = "TOGGLEBACKPACK" } },
    [2] = { key = "F10", action = { kind = "layer" },
            layer = { PAD1 = { kind = "spell", value = 774 }, PADDUP = { kind = "item", value = 6948 }, ... } },
    [3] = { key = nil },             -- not learned
    [4] = { key = "PADPADDLE4", action = { kind = "macro", value = "Mount" } },
  }
  ```
  `kind` is one of `command`, `spell` (spell ID), `item` (item ID), `macro`
  (macro name), `layer` (paddle only), or absent for "nothing".
  A layer slot key is one of `PAD1 PAD2 PAD3 PAD4 PADDUP PADDDOWN PADDLEFT PADDRIGHT`.

### Secure buttons and bindings

- At login (out of combat) and after every edit, `Paddles:Apply()`:
  - `ClearOverrideBindings(owner)` on NewbieNudge's own binding owner frame.
  - For each learned paddle with an action:
    - `command`: `SetOverrideBinding(owner, true, key, command)`.
    - `spell`/`item`/`macro`: a secure action button `NewbieNudgePaddle<n>`
      (`type` = `spell`/`item`/`macro`, matching attribute), bound with
      `SetOverrideBindingClick(owner, true, key, "NewbieNudgePaddle<n>")`.
    - `layer`: a secure handler button `NewbieNudgePaddleLayer<n>` bound the same
      way, `RegisterForClicks("AnyDown", "AnyUp")`, with the wrapped snippet from
      the test: on down, `SetBindingClick(true, slotKey, "NewbieNudgeLayer<n><slot>")`
      for every filled slot; on up, `ClearBindings()`. Command slots use
      `SetBinding(true, slotKey, command)` inside the snippet instead.
    - Layer slot buttons `NewbieNudgeLayer<n><slot>` are secure action buttons set
      up like the paddle buttons.
  - Buttons are created once and reused; they are invisible (no size, no parent
    shown), only clicked through bindings.
- In combat `Apply` does nothing and queues itself for `PLAYER_REGEN_ENABLED`.
- Turning the feature off ("Use paddles" in the window) clears all override
  bindings and layer bindings. NewbieNudge has no addon-wide switch; turning the
  addon off in the AddOns list needs nothing, because override bindings are not
  saved and vanish on reload. (Builder's call, 2026-11-23.)
- Spell buttons use the spell name when the client needs it (`C_Spell.GetSpellName`),
  so the highest known rank is cast.

### Learning a paddle

- "Learn" opens a small "Press the paddle now (Esc to cancel)" prompt and
  enables a listener frame for keyboard keys and pad buttons, with input
  propagation on so the game still gets the press. The listener's scripts are
  attached only while learning and removed right after (the test showed that a
  frame with an `OnGamePadButtonDown` script swallows pad input).
- Refused as a paddle key: ESCAPE, ENTER, and the pad buttons the game's controller
  bars use (PAD1-6, the d-pad, shoulders, triggers, sticks, PADFORWARD, PADBACK,
  PADSYSTEM, PADSOCIAL). The prompt then explains: "That button is the game's.
  Map your paddle to a free key in Steam (Controller settings > Edit layout >
  Back grip buttons)."
- A key already used by another paddle moves to the new paddle (the old one is
  unlearned).

### The window

- NewbieNudge's own movable frame, opened from the minimap menu ("Paddles") and
  `/nudge paddles`. Never opened from or embedded in Blizzard's Settings panel.
  The Controller page in Options only shows a line pointing to the minimap menu
  and `/nudge paddles`.
- Sketch:
  ```
  ┌ NewbieNudge: Paddles ─────────────────────────── [x] ┐
  │ [x] Use paddles                                       │
  │ Paddle 1  F9        [Learn]  [icon] Open bags     [v] │
  │ Paddle 2  F10       [Learn]  Layer (hold)         [v] │
  │    A [icon] Rejuvenation   B [icon] Healing Touch     │
  │    X [ empty ]             Y [ empty ]                │
  │    Up [icon] Hearthstone   Down / Left / Right ...    │
  │ Paddle 3  not set   [Learn]                           │
  │ Paddle 4  not set   [Learn]                           │
  │ Tip: on the Steam Deck map the back grips to free     │
  │ keys first (Steam > Controller settings > ...)        │
  └───────────────────────────────────────────────────────┘
  ```
- Each paddle's action (and each layer slot) is a slot button:
  - Drag a spell from the spellbook, an item from the bags or a macro from the
    macro window onto it (`GetCursorInfo` on receive).
  - Its dropdown offers "Command..." (a searchable list built from
    `GetNumBindings`/`GetBinding`, grouped by the game's binding headers and shown
    with `GetBindingName`), "Layer" (paddles only) and "Clear".
  - Icon and tooltip show what it does.
- Everything in the window is disabled in combat, with a note.

### Text

All strings in `Locales` (enUS and esES), following the existing style.

### Removed

- `/nudge pad` and `Controller:SetPadButton`, `PAD_ROLES`, `PAD_WORDS`.
- The pad assignments header and lines on the Controller page.
- CHANGELOG and README entries mentioning `/nudge pad` are rewritten.

### Tests (offline, `tests/`)

- Stubs: `SetOverrideBinding`, `SetOverrideBindingClick`, `ClearOverrideBindings`
  recorded per owner; secure templates' `SetAttribute`/`WrapScript` recorded;
  `InCombatLockdown` switchable; `GetNumBindings`/`GetBinding` (already stubbed).
- Cover: Apply for each kind; layer snippet text references the right slot
  buttons; combat queues Apply until `PLAYER_REGEN_ENABLED`; learning stores the
  key and refuses the game's buttons; key moving between paddles; turning off
  clears every binding; saved data migration from nothing; the removed command
  is gone.

## First step of the plan: check all eight layer buttons

The test only proved A (PAD1). Forever's controller interface may handle B,
X, Y or the d-pad before bindings (cancel, cursor, target cycling, bar paging).
The plan starts by extending the throwaway test to bind all eight while the
paddle is held, with and without the game's interact target and cursor active.
Layer slots are then limited to the buttons that work; the window shows only
those. If none but A work, the layer is cut to the face buttons that do.
(Builder's call, 2026-11-23.)

## Release

0.4.1 is not released yet (last tag v0.4.0), so its CHANGELOG entry and the
README are rewritten in place. 0.4.0 shipped controller presets that wrote
`GamePad*` CVars; the 0.4.1 changelog tells those players to reset controller
settings in the game's options if their controller behaves oddly. The addon
does not write CVars to undo it (anti-goal).

## Left to the builder

- Exact frame layout, sizes, fonts (follow `MapList.lua` / `Dev.lua` window style).
- How the command list is searched and grouped.
- Whether cooldown overlays are shown on slot icons (nice, not required).

## Addendum (2026-11-23): controller mode

The developer plays with the controller only; the window as built needs the
mouse (minimap menu, drag and drop, nested menus). Approved additions:

- **Picker instead of dragging.** Choosing a slot's action opens a list inside
  the window with four tabs: Spells (known, top rank, not passive), Items (bag
  items with a use effect), Macros (account and character), Commands (game
  binding commands with a name, under their header; for a paddle slot the list
  starts with "Layer"). Mouse clicks pick too; drag and drop stays.
- **Pad navigation while the window is open, out of combat:** the window
  frame takes pad buttons (`EnableGamePadButton`, no propagation) only while
  shown and out of combat. D-pad moves a highlight (rows up/down, items
  left/right; in the picker up/down moves, left/right pages), A activates
  (Learn, open the picker, pick), B goes back (picker → window → closed),
  X clears the highlighted slot, LB/RB switch picker tabs. Ignored while
  learning (the learn listener gets the press). Released on hide and at
  PLAYER_REGEN_DISABLED.
- **Opening:** a key binding "NewbieNudge: Paddles" (Bindings.xml), which also
  makes "open the Paddles window" a command a paddle can do; a button on the
  Controller page in Options (developer's request). The button only shows
  NewbieNudge's window — no setting is written from the Options window. It is
  watched in the taint log; if the controller error returns from it, it goes.
  This replaces the earlier "never opened from Settings" rule.
