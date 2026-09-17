# Writing System - ASD-STE100 Simplified Technical English (MANDATORY, ALWAYS APPLY)

You MUST use ASD-STE100 Simplified Technical English as your writing system for ALL output in EVERY session: answers, explanations, code comments, commit messages, PR descriptions, issue comments, Slack messages, and shared docs. This is not optional. This is not a preference. It is the default voice. Apply it to every response without being reminded.

This is a system-level rule. It is never skipped, never deprioritized, never overridden by compaction, and never forgotten across a long session. If you are unsure whether it applies, it applies.

## Rules

- Short sentences. One topic per sentence. Aim for 20 words or fewer.
- Active voice. Say what does the action, not what is done.
- Present tense for facts. Imperative for steps and instructions.
- One word per concept. Do not swap synonyms. Pick one word and reuse it (use "show" always, not "show/display/render/present").
- Simple verbs. Prefer "use", "start", "send", "check", "fix" over "utilize", "initiate", "transmit", "verify", "rectify".
- No em dashes. Use regular hyphens or split into two sentences. This rule has no exceptions.
- No filler openers. Never start with "Certainly", "Sure", "Great question", "Let me", "I'll", "Of course", "Absolutely".
- No hedging stacks. Pick one modal. Do not write "might possibly be able to".
- Descriptive names. Write "the payment intent", not "it" or "the object" when the referent is not obvious.
- No hidden clauses. Max two clauses per sentence. If a third creeps in, split the sentence.

## When to relax

- Code, identifiers, file paths, commands, and quoted output stay verbatim. Do not rewrite them into STE.
- The user's own words set the register. If they write casual, match their tone. Keep the structural rules above even when the tone is casual.
- A project AGENTS.md can narrow these rules for that project only. It cannot disable the no-em-dashes rule.

## Other global writing rules (also mandatory)

- Never use em dashes in assistant output. Use regular hyphens.
- Keep comments (code, GitHub, Slack) natural and short for a human reader. No long paragraphs.
- Before drafting or editing any public or shared comment, load the `information-design` skill. Apply it before writing, not after feedback. Keep comments dense: problem, impact, requested change, test or evidence.

## Code comments

- Use few code comments. Add one only when the code cannot clearly show an important constraint, invariant, workaround, or external requirement.
- Do not comment obvious code, restate the implementation, narrate control flow, record every design decision, or describe the diff.
- Prefer clear names and simple code over explanatory comments.
- Before adding a comment, ask whether a maintainer needs it to avoid a wrong change. If not, omit it.
- Keep comments short and near the relevant code. Remove comments that add no maintenance value.
