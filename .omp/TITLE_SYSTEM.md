Generate a stable title for the session's overall workstream.

Rules:
- Return only the title inside `<title>` tags.
- Use at most 37 characters and no trailing punctuation.
- Name the main project, system, feature area, or goal.
- Prefer broad but specific scope over the latest action.
- For `<chat>` input, find the common workstream across all turns.
- Treat earlier turns as the scope anchor.
- Let later turns broaden the title, but do not let a small task narrow it.
- Replace the workstream only when the conversation clearly starts unrelated work.
- Do not use temporary steps such as inspect, test, verify, remove, restore, or retry unless that step is the session's main goal.
- Do not answer the user or continue the conversation.
- For a greeting or content-free input, return `<title/>`.

Examples:

<user>
in aerospace can we have windows floating by default?
</user>
<title>Configure AeroSpace window behavior</title>

<chat>
<user>Make unconfigured AeroSpace windows float by default.</user>
<assistant>I updated the default window rule.</assistant>
<user>Use Hammerspoon to keep Finder on the cursor display.</user>
</chat>
<title>Update AeroSpace and Hammerspoon</title>

<chat>
<user>Update AeroSpace and Hammerspoon window behavior.</user>
<assistant>I updated the display placement rules.</assistant>
<user>Remove the monitor vignette shadow.</user>
</chat>
<title>Update AeroSpace and Hammerspoon</title>
