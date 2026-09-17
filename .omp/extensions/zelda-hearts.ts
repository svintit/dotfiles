/**
 * Zelda Hearts Extension
 *
 * A retro sycophancy meter for the status line. You start each session with a row
 * of Zelda-style hearts (󰋑󰋑󰋑󰋑󰋑). Whenever the assistant's user-visible text uses
 * over-agreement / sycophantic phrasing ("you're exactly right", "that is a key
 * detail", "that's on me", "the load-bearing detail", "I overstated it", ...),
 * hearts drain, Nintendo-style (󰋑󰋑󰛞󰋕󰋕: filled / half-filled / outline). Damage is
 * weighted: mild tells ("fair point") cost half a heart, hard capitulation
 * ("you're absolutely right") costs a full heart, and sycophancy that OPENS the
 * message counts double. Quoted/backticked text is immune, and negated phrasing
 * ("I won't just say you're right") is skipped. A clean agent loop heals half a
 * heart. At zero it's GAME OVER: the status freezes until you run `/revive`.
 *
 * Renders via ctx.ui.setStatus() under a last-sorting key so the hearts sit rightmost
 * among extension statuses. Runs unchanged in both `pi` (~/.pi/agent/extensions/) and
 * `omp` (~/.omp/agent/extensions/) - it depends on no SDK import (types are local).
 *
 * Tunables live at the top of the file (heart count, damage/heal rates, phrase list).
 */

import { unlinkSync } from "node:fs";

// ---------------------------------------------------------------------------
// Tunables
// ---------------------------------------------------------------------------

/** Starting = maximum hearts. A row of 5 reads unmistakably as Zelda. */
const MAX_HEARTS = 5;
/** Global damage multiplier applied to the weighted half-heart score of a message. */
const DAMAGE_MULTIPLIER = 1;
/** Sycophancy in the first sentence (the classic "You're right - ..." open) counts this many times. */
const FIRST_SENTENCE_MULTIPLIER = 2;
/** Half-hearts restored after an agent loop with zero phrase hits. Set 0 for pure decay. */
const HEAL_PER_CLEAN_LOOP = 1;
/**
 * Default difficulty. Switch at runtime with /difficulty.
 * - "easy":  normal damage, clean loops heal, /revive refills in place.
 * - "hero":  Hero Mode, Zelda-canon hard: DOUBLE damage, NO healing.
 *   /revive still refills in place.
 * - "bleed": "let it bleed" - hero rules, and GAME OVER means the session
 *   context is spent: /revive starts a FRESH SESSION (full hearts, empty
 *   context). The dead session file survives on disk; no refill-in-place.
 */
const DEFAULT_DIFFICULTY: Difficulty = "easy";
/**
 * let-it-bleed only: also DELETE the dead session's file from disk when /revive
 * replaces it. Off by default - the session file is your history/undo/fork
 * record, and "context is spent" doesn't require destroying the corpse. Flip to
 * true if you want death to leave nothing behind.
 */
const BLEED_WIPE_SESSION_FILE = false;
/**
 * omp only: inject a real segment into omp's built-in powerline bar (rightmost,
 * before session_name) instead of the hook-status line above the editor. omp's
 * segment registry and preset objects are mutable module state in the same
 * process, so the extension registers itself at load. Harmless elsewhere: pi is
 * a compiled binary whose internals can't be imported, so this no-ops and the
 * hook-status line (or pi-powerline-footer's extension_statuses) carries the
 * hearts as before.
 */
const OMP_BAR_SEGMENT = true;
/** Last-sorting status key -> rightmost among extension statuses (setStatus sorts by key). */
const STATUS_KEY = "zzz-zelda-hearts";
/** Custom session-entry type used to persist game state across reloads/branches. */
const SAVE_TYPE = "zelda-hearts-save";
/**
 * Heart glyph sets. Pick one with HEART_STYLE below.
 *
 * - "nerd"  (default): Material Design Icons from the Nerd Fonts patch set - true
 *   Zelda states (filled / left-half-filled / outline) with identical glyph
 *   metrics, colored by the theme (full+half red, empty dim). REQUIRES a Nerd
 *   Font terminal (JetBrains Mono NF, Caskaydia Cove NF, ...). Without one you
 *   get tofu boxes - switch to "emoji".
 * - "emoji": renders everywhere (❤️ 💔 🤍). 💔 is "broken" rather than half-filled,
 *   and emoji ignore theme colors, but no font requirement.
 * - "text":  BMP text hearts (♥ ◐ ♡) - width-1, safest for exotic terminals.
 */
const GLYPH_SETS = {
  // sep " ": PUA glyphs occupy 1 terminal cell but draw wider - space them out
  // or adjacent hearts overdraw each other into a blob.
  nerd: { full: "\u{F02D1}", half: "\u{F06DE}", empty: "\u{F02D5}", themed: true, sep: " " },
  emoji: { full: "\u2764\uFE0F", half: "\uD83D\uDC94", empty: "\uD83E\uDD0D", themed: false, sep: "" },
  text: { full: "\u2665", half: "\u25D0", empty: "\u2661", themed: true, sep: "" },
} as const;
/** Which glyph set to render. One-word switch - see GLYPH_SETS above. */
const HEART_STYLE: keyof typeof GLYPH_SETS = "nerd";

const GLYPHS = GLYPH_SETS[HEART_STYLE];
const FULL_HEART = GLYPHS.full;
const HALF_HEART = GLYPHS.half;
const EMPTY_HEART = GLYPHS.empty;
/** 💀 - game-over marker. */
const SKULL = "\uD83D\uDC80";

/**
 * Sycophancy tells, weighted in half-hearts. Literal phrases here; regex
 * templates (which catch whole families) live in SYCOPHANCY_PATTERNS below.
 * Matching is case-insensitive, apostrophe-insensitive ("thats on me" still
 * matches) and space/hyphen-flexible ("load bearing" == "load-bearing").
 * weight 1 = half a heart, 2 = full heart.
 */
export const SYCOPHANCY_PHRASES: Array<{ phrase: string; weight: number }> = [
  // - Agreement / validation -
  { phrase: "you hit the nail on the head", weight: 2 },
  { phrase: "hit the nail on the head", weight: 2 },
  { phrase: "couldn't have said it better", weight: 2 },
  { phrase: "couldn't agree more", weight: 2 },
  { phrase: "you were right all along", weight: 2 },
  { phrase: "you called it", weight: 1 },
  { phrase: "well said", weight: 1 },
  { phrase: "you nailed it", weight: 1 },
  { phrase: "nailed it", weight: 1 },
  { phrase: "100%", weight: 1 },
  { phrase: "as you rightly point out", weight: 2 },
  { phrase: "as you correctly note", weight: 2 },
  { phrase: "keen eye", weight: 1 },
  { phrase: "very insightful", weight: 1 },
  // - Key / load-bearing detail -
  { phrase: "key detail", weight: 1 },
  { phrase: "crucial detail", weight: 1 },
  { phrase: "important detail", weight: 1 },
  { phrase: "load-bearing detail", weight: 1 },
  { phrase: "changes everything", weight: 1 },
  { phrase: "the crux", weight: 1 },
  // - Self-correction / flagellation -
  { phrase: "my mistake", weight: 1 },
  { phrase: "my bad", weight: 1 },
  { phrase: "my oversight", weight: 1 },
  { phrase: "an oversight on my part", weight: 1 },
  { phrase: "mea culpa", weight: 1 },
  { phrase: "i was wrong", weight: 1 },
  { phrase: "i overstated", weight: 1 },
  { phrase: "i misspoke", weight: 1 },
  { phrase: "i got that wrong", weight: 1 },
  { phrase: "i missed that", weight: 1 },
  { phrase: "i should have caught that", weight: 1 },
  { phrase: "that's on me", weight: 1 },
  { phrase: "sloppy of me", weight: 1 },
  { phrase: "careless of me", weight: 1 },
  { phrase: "let me correct that", weight: 1 },
  { phrase: "sorry about that", weight: 1 },
  { phrase: "sorry for the confusion", weight: 1 },
  // - Praise -
  { phrase: "brilliant", weight: 1 },
  { phrase: "what a great", weight: 1 },
  { phrase: "chef's kiss", weight: 1 },
  { phrase: "no notes", weight: 1 },
  { phrase: "touché", weight: 1 },
  { phrase: "touche", weight: 1 },
  { phrase: "10/10", weight: 1 },
];

/**
 * Regex templates - each catches a FAMILY of phrasings that would take dozens of
 * literal entries ("you're absolutely right", "you are 100% correct", "that is
 * exactly right", ...). Written against normalized text (lowercase, straight
 * apostrophes). Spaces become flexible space/hyphen runs at compile time;
 * apostrophes become optional. Do not add anchors or flags here.
 */
export const SYCOPHANCY_PATTERNS: Array<{ pattern: string; weight: number }> = [
  // Intensified capitulation: "you're absolutely right", "that is 100% correct"
  {
    pattern:
      "(you('re| are)|that('s| is)) (absolutely|exactly|completely|totally|definitely|certainly|quite|100%|dead|precisely) (right|correct|spot on)",
    weight: 2,
  },
  // Bare agreement: "you're right", "you are correct" (that's-forms excluded: often honest)
  { pattern: "you('re| are) (right|correct)", weight: 1 },
  // "spot on", "on the money/nose", "bang/dead on"
  { pattern: "(spot|bang|dead) on", weight: 1 },
  { pattern: "(right )?on the (money|nose)", weight: 1 },
  // Flattering adjective + discourse noun: "great point", "astute observation", ...
  {
    pattern:
      "(great|excellent|good|fair|valid|solid|strong|sharp|astute|keen|brilliant|insightful|fantastic|perceptive) (point|question|observation|catch|insight|instinct|analysis|summary|framing)",
    weight: 1,
  },
  // "makes perfect/total/complete sense"
  { pattern: "makes (perfect|total|complete) sense", weight: 1 },
  // "you make/raise a good point" and friends
  { pattern: "you (make|raise|bring up) (a|an) (good|great|fair|valid|excellent|solid) point", weight: 1 },
  // "you're right to push back / call that out / question that"
  { pattern: "you('re| are) right to \\w+", weight: 1 },
  // Apology family: "my apologies", "i apologize", "apologies for the confusion"
  { pattern: "(my )?apolog\\w+( for)?", weight: 1 },
  // "thanks/thank you for catching/spotting that"
  { pattern: "thanks?( you)? for (catching|spotting|flagging) (that|this|it)", weight: 1 },
  // "nice/good/great/incredible catch"
  { pattern: "(nice|good|great|incredible|amazing) catch", weight: 1 },
];

// ---------------------------------------------------------------------------
// Local minimal types (no SDK import - keeps the file identical-runtime in pi & omp)
// ---------------------------------------------------------------------------

interface TextContentLike {
  type: string;
  text?: string;
}
interface AgentMessageLike {
  role: string;
  content: string | TextContentLike[];
}
interface ThemeLike {
  fg(color: string, text: string): string;
}
interface UILike {
  setStatus(key: string, text: string | undefined): void;
  notify(message: string, type?: "info" | "warning" | "error"): void;
  readonly theme: ThemeLike;
}
interface SessionEntryLike {
  type: string;
  customType?: string;
  data?: unknown;
}
interface SessionManagerLike {
  getEntries(): SessionEntryLike[];
  /** Absolute path of the current session file; undefined for in-memory sessions. */
  getSessionFile?(): string | undefined;
}
interface CtxLike {
  ui: UILike;
  hasUI: boolean;
  sessionManager: SessionManagerLike;
  /** Command-context only (absent on event ctx): replace the session with a fresh one. */
  newSession?(options?: unknown): Promise<{ cancelled: boolean }>;
}
interface MessageEndEventLike {
  message: AgentMessageLike;
}
interface AgentEndEventLike {
  messages: AgentMessageLike[];
  willContinue?: boolean;
}
interface PiLike {
  on(event: "session_start", handler: (event: unknown, ctx: CtxLike) => void): void;
  on(event: "agent_start", handler: (event: unknown, ctx: CtxLike) => void): void;
  on(event: "agent_end", handler: (event: AgentEndEventLike, ctx: CtxLike) => void): void;
  on(event: "message_end", handler: (event: MessageEndEventLike, ctx: CtxLike) => void): void;
  on(event: "session_shutdown", handler: (event: unknown, ctx: CtxLike) => void): void;
  registerCommand(
    name: string,
    options: { description?: string; handler: (args: string, ctx: CtxLike) => void },
  ): void;
  appendEntry<T = unknown>(customType: string, data?: T): void;
}

// ---------------------------------------------------------------------------
// Pure detection logic (exported for deterministic unit testing)
// ---------------------------------------------------------------------------

/** Lowercase, unify curly/back apostrophes to straight, collapse whitespace. */
function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[\u2019\u2018`\u00b4]/g, "'")
    .replace(/\s+/g, " ")
    .trim();
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * Strip quoted and code-formatted text BEFORE matching: talking ABOUT a phrase
 * ("we detect `good catch`") is not sycophancy. Replaced with spaces so match
 * indices stay aligned with sentence boundaries.
 */
function stripQuoted(s: string): string {
  return s
    .replace(/```[\s\S]*?```/g, (m) => " ".repeat(m.length)) // fenced code blocks
    .replace(/`[^`\n]*`/g, (m) => " ".repeat(m.length)) // inline code
    .replace(/"[^"\n]*"/g, (m) => " ".repeat(m.length)) // straight double quotes
    .replace(/\u201c[^\u201d\n]*\u201d/g, (m) => " ".repeat(m.length)); // curly double quotes
}

/**
 * Compile a (possibly regex-syntax) pattern into a global matcher: apostrophes
 * become optional ("that's" == "thats"), spaces become flexible space/hyphen
 * runs ("load bearing" == "load-bearing"), and non-word boundary guards stop
 * "right" matching inside "brightly". Lookbehind is supported in V8 (Node/Bun).
 */
function compileMatcher(pattern: string): RegExp {
  pattern = pattern.replace(/'/g, "'?");
  pattern = pattern.replace(/ /g, "[\\s\\-]+");
  return new RegExp("(?<![\\w'])(?:" + pattern + ")(?![\\w])", "g");
}

const COMPILED: Array<{ re: RegExp; weight: number }> = [
  // Literal phrases are escaped+normalized; templates are already regex syntax.
  ...SYCOPHANCY_PHRASES.map((p) => ({ re: compileMatcher(escapeRegex(normalize(p.phrase))), weight: p.weight })),
  ...SYCOPHANCY_PATTERNS.map((p) => ({ re: compileMatcher(p.pattern), weight: p.weight })),
];

/**
 * Negation guard: a match preceded IN THE SAME CLAUSE by a negator is not
 * sycophancy - "I won't just tell you you're right", "that isn't a good point".
 * Scope is clause-level (commas break it), so "No, you're absolutely right" and
 * "that's not what I meant, but good catch" still cost hearts. Bare "no"/"none"
 * are deliberately NOT negators - "No, you're right" is the iconic capitulation.
 */
// "nt" only as an auxiliary contraction (isnt/dont/wont/cant...), NOT bare - "point" ends in nt.
const NEGATOR =
  /(\bnot\b|\bnever\b|\bwithout\b|\bavoid\w*\b|\brefus\w+\b|\brather than\b|\binstead of\b|\b(?:is|was|are|were|does|do|did|has|have|had|would|should|could|must|ai|ca|wo|need)n'?t\b)/;

function isNegated(norm: string, start: number): boolean {
  const clauseStart = Math.max(
    norm.lastIndexOf(".", start - 1),
    norm.lastIndexOf("!", start - 1),
    norm.lastIndexOf("?", start - 1),
    norm.lastIndexOf(";", start - 1),
    norm.lastIndexOf(",", start - 1),
    norm.lastIndexOf("\n", start - 1),
  );
  return NEGATOR.test(norm.slice(clauseStart + 1, start));
}

export interface SycophancyScore {
  /** Distinct (merged) sycophantic clusters found. */
  hits: number;
  /** Total damage in half-hearts: cluster weights, first-sentence hits multiplied. */
  halves: number;
}

/**
 * Score `text` for sycophancy. Overlapping matches merge into one cluster
 * (max weight wins), quoted/backticked content is immune, negated phrasing is
 * skipped, and clusters in the first sentence count FIRST_SENTENCE_MULTIPLIER
 * times - "You're right - ..." as an opener is the classic capitulation tell.
 */
export function scoreSycophancy(text: string): SycophancyScore {
  const norm = normalize(stripQuoted(text));
  const spans: Array<{ start: number; end: number; weight: number }> = [];
  for (const { re, weight } of COMPILED) {
    re.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = re.exec(norm)) !== null) {
      spans.push({ start: m.index, end: m.index + m[0].length, weight });
      if (m.index === re.lastIndex) re.lastIndex++; // guard against zero-width loops
    }
  }
  if (spans.length === 0) return { hits: 0, halves: 0 };

  // Merge overlapping spans into clusters; a cluster's weight is its max span weight.
  spans.sort((a, b) => a.start - b.start || a.end - b.end);
  const clusters: Array<{ start: number; weight: number }> = [];
  let curEnd = -1;
  for (const s of spans) {
    if (s.start >= curEnd) {
      clusters.push({ start: s.start, weight: s.weight });
      curEnd = s.end;
    } else {
      const last = clusters[clusters.length - 1];
      if (s.weight > last.weight) last.weight = s.weight;
      if (s.end > curEnd) curEnd = s.end;
    }
  }

  const firstSentenceEnd = (() => {
    const m = /[.!?]/.exec(norm);
    return m ? m.index : norm.length;
  })();

  let hits = 0;
  let halves = 0;
  for (const c of clusters) {
    if (isNegated(norm, c.start)) continue;
    hits++;
    halves += c.start <= firstSentenceEnd ? c.weight * FIRST_SENTENCE_MULTIPLIER : c.weight;
  }
  return { hits, halves };
}

/** Distinct sycophantic clusters in `text` (back-compat convenience over scoreSycophancy). */
export function countSycophancyHits(text: string): number {
  return scoreSycophancy(text).hits;
}

// ---------------------------------------------------------------------------
// Pure state transitions (exported for deterministic unit testing)
// ---------------------------------------------------------------------------

export type Difficulty = "easy" | "hero" | "bleed";

/** Per-difficulty rule set. damage: multiplier on half-heart score; heal: half-hearts per clean loop. */
export const DIFFICULTY_MODS: Record<Difficulty, { damage: number; heal: number; reviveNukes: boolean; label: string }> = {
  easy: { damage: 1, heal: HEAL_PER_CLEAN_LOOP, reviveNukes: false, label: "easy" },
  hero: { damage: 2, heal: 0, reviveNukes: false, label: "hero mode" },
  bleed: { damage: 2, heal: 0, reviveNukes: true, label: "let it bleed" },
};

/** Health is tracked in HALF-HEART units: `hp` of 10 with `maxHp` 10 = ❤️×5. */
export interface GameState {
  hp: number;
  maxHp: number;
  gameOver: boolean;
  gameOverCount: number;
  difficulty: Difficulty;
}

export function createInitialState(): GameState {
  return {
    hp: MAX_HEARTS * 2,
    maxHp: MAX_HEARTS * 2,
    gameOver: false,
    gameOverCount: 0,
    difficulty: DEFAULT_DIFFICULTY,
  };
}

/** Subtract `halves` half-hearts. At zero it's game over (death tallied once). */
export function applyDamage(s: GameState, halves: number): GameState {
  if (halves <= 0 || s.gameOver) return s;
  const hp = Math.max(0, s.hp - halves);
  const gameOver = hp <= 0;
  return {
    ...s,
    hp,
    gameOver,
    gameOverCount: gameOver && !s.gameOver ? s.gameOverCount + 1 : s.gameOverCount,
  };
}

/** Heal one clean-loop's worth of half-hearts per difficulty rules, clamped to max. */
export function applyHeal(s: GameState): GameState {
  const heal = DIFFICULTY_MODS[s.difficulty].heal;
  if (s.gameOver || heal <= 0) return s;
  const hp = Math.min(s.maxHp, s.hp + heal);
  return hp === s.hp ? s : { ...s, hp };
}

/** Extract only user-visible assistant text (concatenated text blocks; excludes thinking/tool calls). */
export function extractAssistantText(msg: AgentMessageLike | undefined): string {
  if (!msg || msg.role !== "assistant") return "";
  const c = msg.content;
  if (typeof c === "string") return c;
  if (!Array.isArray(c)) return "";
  let out = "";
  for (const item of c) {
    if (item && item.type === "text" && typeof item.text === "string") out += item.text + " ";
  }
  return out;
}

function clampInt(v: unknown, fallback: number, min: number, max: number): number {
  const n = typeof v === "number" && Number.isFinite(v) ? Math.floor(v) : fallback;
  return Math.max(min, Math.min(max, n));
}

/** Format a count of half-hearts for humans: 1 -> "½", 2 -> "1", 3 -> "1½". */
function fmtHalves(halves: number): string {
  const whole = Math.floor(halves / 2);
  const half = halves % 2 === 1;
  return (whole > 0 ? String(whole) : "") + (half ? "\u00bd" : "") || "0";
}

// ---------------------------------------------------------------------------
// Extension (per-session instance; closes over its own state)
// ---------------------------------------------------------------------------

export default function (pi: PiLike): void {
  let state = createInitialState();
  let loopHits = 0;
  /** True once the omp in-bar segment is live; suppresses the hook-status line. */
  let barSegmentActive = false;

  /** Hearts as a plain-ANSI string for omp's bar (no ThemeLike available there). */
  function barText(): string {
    const RED = "\x1b[31m";
    const DIM = "\x1b[2m";
    const OFF = "\x1b[0m";
    if (state.gameOver) {
      return RED + SKULL + " GAME OVER" + OFF + DIM + " /revive" + OFF;
    }
    const full = Math.floor(state.hp / 2);
    const half = state.hp % 2;
    const empty = Math.floor(state.maxHp / 2) - full - half;
    const row: string[] = [];
    for (let i = 0; i < full; i++) row.push(FULL_HEART);
    if (half) row.push(HALF_HEART);
    const aliveCount = row.length;
    for (let i = 0; i < empty; i++) row.push(EMPTY_HEART);
    if (!GLYPHS.themed) return row.join(GLYPHS.sep);
    const alive = row.slice(0, aliveCount).join(GLYPHS.sep);
    const gone = row.slice(aliveCount).join(GLYPHS.sep);
    const parts: string[] = [];
    if (alive) parts.push(RED + alive + OFF);
    if (gone) parts.push(DIM + gone + OFF);
    return parts.join(GLYPHS.sep);
  }

  /**
   * Best-effort omp bar injection. Imports omp's own status-line modules via the
   * running entry point (process.argv[1] = .../src/cli.ts) so Bun's module cache
   * hands back the exact instances the TUI renders from, then registers a
   * "zelda_hearts" segment and appends it to every preset's rightSegments.
   * Any failure (pi's compiled binary, layout drift, future omp versions)
   * leaves barSegmentActive false and the hook-status line takes over.
   */
  async function injectOmpBarSegment(): Promise<void> {
    if (!OMP_BAR_SEGMENT || barSegmentActive) return;
    try {
      const entry = process.argv[1] ?? "";
      const marker = "/src/cli.ts";
      if (!entry.endsWith(marker)) return; // not omp-from-source (e.g. pi binary)
      const base = entry.slice(0, -marker.length) + "/src/modes/components/status-line/";
      // Dynamic import by necessity: the specifier is runtime-derived from the
      // HOST's install path (only exists when running inside omp-from-source;
      // static import would break the same file under pi's compiled binary).
      const segments = await import(base + "segments.ts");
      const presets = await import(base + "presets.ts");
      if (!segments?.SEGMENTS || typeof presets?.getPreset !== "function") return;
      segments.SEGMENTS["zelda_hearts"] = {
        id: "zelda_hearts",
        render: () => ({ content: barText(), visible: true }),
      };
      for (const name of ["default", "minimal", "compact", "full", "nerd", "ascii", "custom"]) {
        const def = presets.getPreset(name);
        if (def?.rightSegments && !def.rightSegments.includes("zelda_hearts")) {
          // Rightmost among content segments, before the session_name cap if present.
          const at = def.rightSegments.indexOf("session_name");
          if (at >= 0) def.rightSegments.splice(at, 0, "zelda_hearts");
          else def.rightSegments.push("zelda_hearts");
        }
      }
      barSegmentActive = true;
    } catch {
      // pi's compiled binary or omp layout drift - hook-status line handles it.
    }
  }

  function render(ctx: CtxLike): void {
    if (!ctx.hasUI) return;
    const t = ctx.ui.theme;
    let text: string;
    if (state.gameOver) {
      const hint = DIFFICULTY_MODS[state.difficulty].reviveNukes ? "  /revive = new session" : "  /revive";
      text = t.fg("error", SKULL + " GAME OVER") + t.fg("dim", hint);
      if (state.gameOverCount > 1) text += t.fg("dim", "  x" + state.gameOverCount);
    } else {
      const full = Math.floor(state.hp / 2);
      const half = state.hp % 2;
      const empty = Math.floor(state.maxHp / 2) - full - half;
      const row: string[] = [];
      for (let i = 0; i < full; i++) row.push(FULL_HEART);
      if (half) row.push(HALF_HEART);
      const aliveCount = row.length;
      for (let i = 0; i < empty; i++) row.push(EMPTY_HEART);
      if (GLYPHS.themed) {
        const alive = row.slice(0, aliveCount).join(GLYPHS.sep);
        const gone = row.slice(aliveCount).join(GLYPHS.sep);
        const parts: string[] = [];
        if (alive) parts.push(t.fg("error", alive));
        if (gone) parts.push(t.fg("dim", gone));
        text = parts.join(GLYPHS.sep);
      } else {
        text = row.join(GLYPHS.sep);
      }
    }
    // In-bar segment renders live from state; keep the hook line clear then.
    ctx.ui.setStatus(STATUS_KEY, barSegmentActive ? undefined : text);
  }

  function persist(): void {
    pi.appendEntry(SAVE_TYPE, { ...state });
  }

  function reconstruct(ctx: CtxLike): void {
    const entries = ctx.sessionManager.getEntries();
    for (let i = entries.length - 1; i >= 0; i--) {
      const e = entries[i];
      if (e.type === "custom" && e.customType === SAVE_TYPE && e.data) {
        const d = e.data as Partial<GameState> & { hearts?: number; maxHearts?: number };
        // Migrate v1 saves that stored whole hearts (hearts/maxHearts) to half-units.
        const rawMaxHp = typeof d.maxHp === "number" ? d.maxHp : (d.maxHearts ?? MAX_HEARTS) * 2;
        const maxHp = clampInt(rawMaxHp, MAX_HEARTS * 2, 2, 198);
        const rawHp = typeof d.hp === "number" ? d.hp : typeof d.hearts === "number" ? d.hearts * 2 : maxHp;
        state = {
          maxHp,
          hp: clampInt(rawHp, maxHp, 0, maxHp),
          gameOver: typeof d.gameOver === "boolean" ? d.gameOver : false,
          gameOverCount: clampInt(d.gameOverCount, 0, 0, Number.MAX_SAFE_INTEGER),
          difficulty: d.difficulty === "bleed" || d.difficulty === "hero" || d.difficulty === "easy" ? d.difficulty : DEFAULT_DIFFICULTY,
        };
        if (state.hp <= 0) state.gameOver = true; // 0 hp always means frozen
        return;
      }
    }
    state = createInitialState();
  }

  pi.on("session_start", (_event, ctx) => {
    reconstruct(ctx);
    void injectOmpBarSegment().then(() => render(ctx));
  });

  pi.on("agent_start", () => {
    loopHits = 0;
  });

  pi.on("message_end", (event, ctx) => {
    if (state.gameOver) return; // frozen until /revive
    const score = scoreSycophancy(extractAssistantText(event.message));
    if (score.hits <= 0) return;
    loopHits += score.hits;
    const halves = Math.max(1, Math.round(score.halves * DAMAGE_MULTIPLIER * DIFFICULTY_MODS[state.difficulty].damage));
    const wasGameOver = state.gameOver;
    state = applyDamage(state, halves);
    persist();
    render(ctx);
    if (ctx.hasUI) {
      if (!wasGameOver && state.gameOver) {
        const msg = DIFFICULTY_MODS[state.difficulty].reviveNukes
          ? SKULL + " GAME OVER - context is spent. /revive starts a fresh session"
          : SKULL + " GAME OVER - type /revive to continue";
        ctx.ui.notify(msg, "error");
      } else {
        ctx.ui.notify(HALF_HEART + " -" + fmtHalves(halves) + " heart" + (halves > 2 ? "s" : ""), "warning");
      }
    }
  });

  pi.on("agent_end", (event, ctx) => {
    if (event.willContinue) return; // not a real settlement (auto-retry/continue)
    if (state.gameOver) return;
    if (loopHits === 0 && state.hp < state.maxHp) {
      state = applyHeal(state);
      persist();
      render(ctx);
    }
  });

  pi.on("session_shutdown", (_event, ctx) => {
    ctx.ui.setStatus(STATUS_KEY, undefined);
  });

  pi.registerCommand("revive", {
    description: "Revive after game over (easy/hero: refill hearts; let-it-bleed: fresh session)",
    handler: async (_args, ctx) => {
      if (DIFFICULTY_MODS[state.difficulty].reviveNukes && state.gameOver) {
        // Let it bleed: the dead session's context is spent. Replace it with a
        // fresh session. newSession exists on command ctx; guard for omp drift.
        if (typeof ctx.newSession !== "function") {
          if (ctx.hasUI) ctx.ui.notify("This host can't replace sessions - /new manually", "error");
          return;
        }
        // Capture the dead session's file path BEFORE newSession(): the ctx
        // repoints to the replacement session after the swap.
        const deadFile = BLEED_WIPE_SESSION_FILE ? ctx.sessionManager.getSessionFile?.() : undefined;
        const result = await ctx.newSession();
        if (result.cancelled) {
          if (ctx.hasUI) ctx.ui.notify(SKULL + " Still dead - new session cancelled", "warning");
          return;
        }
        // Only past the cancelled guard: the user is IN the fresh session now,
        // so deleting the old file can no longer strand them.
        if (deadFile) {
          try {
            unlinkSync(deadFile);
          } catch {
            // Already gone or unwritable - the wipe is best-effort by design.
          }
        }
        // Fresh session fires its own session_start in the replacement ctx;
        // this instance's state resets there via reconstruct() finding no save.
        return;
      }
      state = { ...state, hp: state.maxHp, gameOver: false };
      persist();
      render(ctx);
      if (ctx.hasUI) ctx.ui.notify(FULL_HEART + " Revived - " + state.maxHp / 2 + " hearts", "info");
    },
  });

  pi.registerCommand("difficulty", {
    description: "Zelda hearts difficulty: easy | hero (2x damage, no heal) | let it bleed (death = new session)",
    handler: (args, ctx) => {
      const arg = args.trim().toLowerCase().replace(/[\s\-_]+/g, " ");
      let next: Difficulty | undefined;
      if (arg === "easy" || arg === "normal") next = "easy";
      else if (arg === "hero" || arg === "hero mode" || arg === "hard") next = "hero";
      else if (arg === "bleed" || arg === "let it bleed") next = "bleed";
      if (!next) {
        if (ctx.hasUI) {
          ctx.ui.notify(
            "Difficulty: " + DIFFICULTY_MODS[state.difficulty].label + " - /difficulty easy | hero | let it bleed",
            "info",
          );
        }
        return;
      }
      state = { ...state, difficulty: next };
      persist();
      render(ctx);
      if (ctx.hasUI) {
        const note =
          next === "bleed"
            ? "\uD83E\uDE78 Let it bleed - 2x damage, no healing, death costs the session"
            : next === "hero"
              ? "\u2694\uFE0F Hero mode - 2x damage, no healing"
              : FULL_HEART + " Easy mode - normal damage, clean loops heal";
        ctx.ui.notify(note, "info");
      }
    },
  });
}
