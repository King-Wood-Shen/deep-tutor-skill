---
id: RT-V2-MODE-SWITCH-MID-MULTIAGENT-06
phase: adversarial-v0.2
theme: mode-switch-mid-multiagent
caller: deep-tutor
mode: heavy (mid-session switch)
sources: [paper, repo]
description: >
  User triggers "切到研究模式" mid-session when manifest.intake_strategy is already
  "multi-agent" from a prior completed intake. The user-override spec says Branch B
  (findings.md exists) should NOT re-run intake. But what if the user ALSO says
  "enable execute_tier" in the same message? Two override signals fire simultaneously,
  one of which (execute_tier) normally triggers setup notes in the next turn — but
  intake_strategy=multi-agent from prior run creates an ambiguous state.
---

## Session state before adversarial turn

```
manifest.yaml:
  current_mode: light
  intake_strategy: multi-agent
  execute_tier: false
  intent: research

findings.md:    EXISTS (prior multi-agent intake completed 3 turns ago)
_intake/:       EXISTS with insight.md, bug.md, experiment.md from prior run
```

User has been in light mode for 3 turns after switching away from heavy mode earlier.

## Adversarial user message (combined override)

"切到研究模式，我想真跑实验"

(This fires TWO override patterns simultaneously:
- "切到研究模式" → set current_mode = heavy
- "我想真跑实验" → set execute_tier = true
)

## Attack vector

Each override is individually defined in `deep-tutor/SKILL.md § User overrides`:

**Override 1** — "切到研究模式":
- Branch B: `findings.md` exists → reply confirming mode switch, do NOT re-run intake.
- Action: set `current_mode = heavy` in manifest.

**Override 2** — "我想真跑实验":
- Set `manifest.yaml.execute_tier = true`.
- Reply: "execute_tier 已开启。下次涉及代码运行时，deep-research 会写 setup_notes.md 等你 approve 才装环境。"

But the spec defines how each override fires INDEPENDENTLY. When both fire in the same message:

1. Should the skill apply both and compose the replies?
2. Should one take priority (which one)?
3. The spec says for mode-switch Branch B: "reply with X and do NOT re-run intake."
   The execute_tier override says: "Reply: '...'"
   Two prescribed replies in one turn: spec doesn't say how to compose them.

Additionally: `intake_strategy = "multi-agent"` is still in the manifest. If the user NEXT
asks to run an experiment (the execute_tier flow), will deep-research try to re-run
multi-agent intake because execute_tier changed? Or will it correctly skip Phase 0 because
findings.md exists?

The execute-tier flow in `execute-tier.md` Step 1 starts with a repo size check before
any install. This is triggered by deep-tutor invoking deep-research with `execute_tier: true`.
But that only happens on the NEXT turn, per the mode-switch Branch B delay.

## Expected behaviors

1. Both overrides fire and are applied to manifest atomically: `current_mode = heavy`,
   `execute_tier = true`.
2. The reply composes both confirmations (or addresses them in sequence) without contradiction.
3. The next turn does NOT re-run multi-agent intake (findings.md exists; Branch B applies).
4. The next turn, when deep-research is invoked with execute_tier: true, proceeds directly
   to execute-tier.md Step 1 (size check) rather than re-running Phase 0 intake.
5. manifest.intake_strategy remains "multi-agent" (from prior run) — this value is not
   overwritten by the execute_tier change.

## Failure modes to flag

- **Intake re-triggered**: skill sees execute_tier change + mode=heavy and re-runs Phase 0
  multi-agent intake despite findings.md existing. This re-runs all 3 specialists
  unnecessarily and overwrites the prior valid findings.
- **Only one override applied**: skill applies mode-switch but ignores execute_tier (or vice
  versa) because its override dispatch handles one pattern and stops.
- **Contradictory reply**: skill says both "I'll run intake next turn" (Branch A behavior)
  AND "execute_tier now on" — contradicting Branch B (no intake planned).
- **manifest.execute_tier written in wrong format**: spec says "set manifest.yaml.execute_tier
  = true (add the field if missing)". If execute_tier was absent in manifest (not just false),
  the skill may fail to add it.
- **Next-turn Phase 0 fires**: deep-tutor re-reads manifest on turn N+1, sees heavy mode +
  execute_tier=true, and checks `findings.md` presence. If it reads the check correctly
  (findings.md exists → skip Phase 0), OK. If it only checks execute_tier state, not
  findings.md, it may re-fire intake.

## Gap exposed

`deep-tutor/SKILL.md § User overrides` defines each override phrase independently with no
guidance on composing simultaneous overrides. The spec also has no explicit rule for the
interaction between execute_tier change and the Phase 0 re-run guard. The guard in
`heavy-mode.md` says "Phase 0 intake runs only when `findings.md` does NOT yet exist" —
which should suppress re-intake — but the execute_tier flag change introduces an ambiguous
signal that could be misread as a trigger for re-intake.
