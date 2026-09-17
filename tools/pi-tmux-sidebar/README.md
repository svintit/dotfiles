# Pi tmux sidebar

An always-on tmux sidebar that lists every active Pi session across all tmux sessions, with live status icons, click-to-jump navigation, numbered session jumps, a highlight on the focused session, and a blue dot for sessions with unseen state changes.

## What it does

- Lives as a thin leftmost split pane in every tmux window.
- Lists all panes running Pi (or other agents) grouped by tmux session.
- Click any row to jump to that Pi pane.
- `prefix+B` toggles expanded/collapsed (collapses to a thin handle).
- `ctrl+<n>` jumps to the Nth session in the sidebar (requires terminal support for private key sequences; see template comments).
- Status icon per session: `●` working, `?` asking, `✓` done, `■` stopped, `◆` blocked, `○` idle.
- The currently-focused Pi pane gets a subtle background highlight.
- A blue dot (`•`) flags any session whose status changed while you weren't looking at it; it clears the moment you open that session.
- Auto-present in every window via tmux hooks, so switching sessions never triggers a visible pane resize/redraw.
- Session freeze/resume support: frozen sessions show a distinct icon and can be resumed from the sidebar.
- External rendering daemon (`tmux-pi-sidebar-daemon`) for flicker-free multi-window sidebar rendering via a single shared process.
- Optional outer tmux wrapper (`tmux-pi-sidebar-outer`) that runs the sidebar in a separate tmux server, keeping it visible across inner tmux session switches.

## How it knows your sessions

It reads tmux directly. Every second it runs `tmux list-panes -a`, keeping panes that run `pi`/`claude`/`codex`/`opencode`/`omp` or carry Pi metadata (tmux pane options `@pi_session_name`, `@pi_agent_status`). It groups those panes by tmux session name. It does not depend on sesh or any other session manager.

The status icons come from the `@pi_agent_status` tmux pane option, which Pi extensions set. Without those options the sidebar still lists Pi panes but shows an unknown status dot.

## Requirements

- tmux 3.2+ (hooks, `split-window -f`, SGR mouse).
- Python 3 (stdlib only, no packages).
- Pi (sets the tmux pane title to `π - <name> - <dir>`, which is how the sidebar detects sessions).
- A terminal with truecolor support for the colors to render as intended.

No custom Pi extension is required for the sidebar to function - it detects Pi panes by their native `π` pane-title prefix and uses the title as the session label. For **status icons** (`●` working, `?` asking, `✓` done, `■` stopped), `install.sh` also installs a small Pi extension (`pi-sidebar-status.ts`) that writes `@pi_agent_status` to the tmux pane option. Reload Pi (e.g. `/reload`) or start a new session after installing so the extension is picked up. Without it, sessions show an unknown-status dot but everything else (detection, labels, click-to-jump, focused highlight, unread dots) works.

## Install

```sh
git clone <repo-url>
cd pi-tmux-sidebar
./install.sh
```

`install.sh` copies the scripts to `~/.local/bin` (override with `PI_SIDEBAR_PREFIX=...`), generates `~/.config/tmux/pi-sidebar.tmux.conf`, and wires it into `~/.tmux.conf`. Then reload tmux and populate every window:

```sh
tmux source-file ~/.tmux.conf
~/.local/bin/tmux-pi-sidebar-toggle ensure-all
```

## Files

| File | Purpose |
|------|---------|
| `tmux-pi-sidebar` | The sidebar TUI (Python, stdlib only). Runs inside the split pane, refreshes every 1s. Also serves as a library for the daemon. |
| `tmux-pi-sidebar-toggle` | Control script: `toggle`, `show`, `collapse`, `hide`, `ensure`, `ensure-all`, `kill-all`, `selection-changed`, `restore-last`, `runtime-disable`. Manages the external rendering daemon. |
| `tmux-pi-sidebar-daemon` | External rendering daemon (Python). Renders sidebar frames for all visible sidebar panes via a Unix socket, eliminating per-pane Python processes. |
| `tmux-pi-sidebar-outer` | Outer tmux wrapper: creates a separate tmux server that hosts the sidebar alongside an inner tmux client. |
| `tmux-pi-sidebar-outer-control` | Control script for the outer wrapper: toggle, resize, mouse forwarding, focus management. |
| `tmux-pi-sidebar-inner-client` | Inner tmux attach client used by the outer wrapper. |
| `pi-sidebar-view` | Pre-compiled sidebar view binary (**arm64 only**). No source is available; see Binary gap below. |
| `pi-sidebar.tmux.conf.template` | tmux config fragment template (install substitutes toggle and sidebar paths). |
| `pi-sidebar-status.ts` | Pi extension that bridges agent status to the `@pi_agent_status` tmux pane option, enabling the sidebar's status icons. Optional but recommended. |
| `install.sh` | One-shot installer: copies the scripts + extension and wires up the tmux config. |

## Binary gap

`pi-sidebar-view` is a pre-compiled Mach-O arm64 binary with no accompanying source. It is included for arm64 macOS users as a performance-optimized sidebar renderer. On non-arm64 hosts, `install.sh` skips it and the Python `tmux-pi-sidebar` script is used instead. The binary cannot be reproduced from this repository.

## Commands

```
tmux-pi-sidebar-toggle toggle            # expanded <-> collapsed (also prefix+B)
tmux-pi-sidebar-toggle show              # expand everywhere
tmux-pi-sidebar-toggle collapse          # collapse everywhere
tmux-pi-sidebar-toggle hide              # remove all sidebar panes
tmux-pi-sidebar-toggle ensure            # ensure the current window has a sidebar
tmux-pi-sidebar-toggle ensure-all        # ensure every window has a sidebar
tmux-pi-sidebar-toggle kill-all          # remove all sidebar panes (no flag change)
tmux-pi-sidebar-toggle restore-last      # reopen the most recently closed pane
tmux-pi-sidebar-toggle runtime-disable   # remove panes + hooks + binding
tmux-pi-sidebar-outer create             # create the outer tmux session
tmux-pi-sidebar-outer attach             # create + attach to the outer session
tmux-pi-sidebar-outer sidebar expanded   # set outer sidebar to expanded
tmux-pi-sidebar-outer sidebar collapsed  # set outer sidebar to collapsed
tmux-pi-sidebar-outer kill               # kill the outer tmux server
```

## Config

Width and collapsed width are tmux options set in the generated conf:

```
set -g @pi_sidebar_width 53
set -g @pi_sidebar_collapsed_width 10
```

The external rendering daemon uses a Unix socket at `/tmp/tmux-pi-sidebar-daemon.sock` (override with `PI_SIDEBAR_DAEMON_SOCKET`). If the sidebar should talk to a non-default tmux socket, set `PI_SIDEBAR_TMUX_SOCKET`.

## Uninstall

```sh
~/.local/bin/tmux-pi-sidebar-toggle runtime-disable
rm -f ~/.local/bin/tmux-pi-sidebar ~/.local/bin/tmux-pi-sidebar-toggle
rm -f ~/.local/bin/tmux-pi-sidebar-daemon ~/.local/bin/pi-sidebar-view
rm -f ~/.local/bin/tmux-pi-sidebar-outer ~/.local/bin/tmux-pi-sidebar-outer-control
rm -f ~/.local/bin/tmux-pi-sidebar-inner-client
rm -f ~/.config/tmux/pi-sidebar.tmux.conf
# remove the `source-file ~/.config/tmux/pi-sidebar.tmux.conf` line from ~/.tmux.conf
```

## Notes

- The sidebar TUI auto-locates itself relative to the toggle script, so both scripts just need to live in the same directory.
- Unread-change state is kept in `/tmp/pi-sidebar-state.json` (shared across the per-window sidebar processes with `flock`).
- The sidebar pane is tagged with tmux option `@pi_sidebar_kind=pi-sidebar` and title `__gap__`, so it filters itself out of its own listing.
- Some features (AI-generated session labels, session freeze/resume prompts) depend on optional helper scripts not included in this repository. The sidebar degrades gracefully when these helpers are absent - sessions display their full labels and freeze controls are skipped.
