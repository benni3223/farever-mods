# Recap collection contract

Checked against the installed Farever 0.3.0.31118 client on 2026-10-08.
`hlboot.dat` SHA-256:
`5f288029b34682fa63d22e90000cb8ff91d23d08fbacc965952a799ba92e452f`.

The native bytecode/type table confirms:

- `ent.Unit.rpcReceiveDamage__impl(Unit, DamageResult): Void` (function 4918)
  is a client notification/display routine. It does not subtract HP. Attribute
  replication and the damage/death notifications can arrive separately.
- `ent.Unit.rpcDisplayHeal__impl(Unit, DamageResult): Void` (4955) runs before
  the local EffectsFeed/floating-number choice. Remote-to-remote floating heals
  can be filtered out by source ownership. Collection must hook this RPC,
  independently of number visibility and other UI mods.
- `st.skill.DamageResult` has `target`, `_amount`, `_kill`, `_critical`,
  `weakSource`, `effect`, and the inherited `skill`. It has no `targetUnit`.
- `DamageResult.get_amount()` (5208) returns `_amount` directly. EffectsFeed
  may multiply it by `getDynamicScalingFactor()` (5220) for displayed numbers.
  Damage, healing and HP reconciliation must share the result's raw units.
- `ent.GameObject.rpcDie__impl(GameObject): Void` (4690) calls the virtual
  death handler. Observe it before that handler can remove the unit/roster data.

Death reports accept notification events for 0.5 seconds after death, matching
the encounter's final-damage grace period. The same report object is updated
while live, then history/recap copies detach both its rows and totals. Repeated
death notifications are identified by player UID and death timestamp.

HP reconstruction requires a previously observed HP baseline and a new sample
that agrees with the entire damage/healing batch. Otherwise the measured HP
and hit segment are visibly marked as samples/estimates. A killing result can
establish zero remaining HP without establishing the exact previous HP. Overkill
only has an exact removed-HP segment when that previous HP was reconciled.
Missing client notifications are never filled with invented hits.

Regression coverage is in `DeathLogTest`, `RecapAccuracyTest`,
`HealingMeterTest`, `TimelineRenderTest` and the existing history tests. The
render test exercises the shared native drawing code with strict Object/Flow
contracts at six widths, including both popup and recap parent types; it is an
offline layout check, not a multiplayer gameplay test.
