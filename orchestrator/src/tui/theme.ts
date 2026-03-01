// tui/theme.ts — ANSI-16 safe color palette + symbols
// Only named colors — works on PuTTY, macOS Terminal.app, Linux, SSH

import chalk from 'chalk';

// --- Colors (chalk@4 named colors = ANSI-16) ---

export const colors = {
  success: chalk.green,
  error: chalk.red,
  warning: chalk.yellow,
  info: chalk.cyan,
  special: chalk.magenta,
  text: chalk.white,
  muted: chalk.gray,
  bold: chalk.bold,
  dim: chalk.dim,
  inverse: chalk.inverse,

  // Composite
  header: chalk.bold.cyan,
  label: chalk.gray,
  value: chalk.white,
  border: chalk.gray,
  borderFocused: chalk.cyan,
} as const;

// --- Agent status dots ---

export const statusDot: Record<string, string> = {
  idle: chalk.green('●'),
  working: chalk.yellow('●'),
  waiting: chalk.cyan('●'),
  error: chalk.red('●'),
  stopped: chalk.gray('●'),
};

// --- Task status symbols ---

export const taskSymbol: Record<string, string> = {
  pending: '[ ]',
  assigned: chalk.yellow('[~]'),
  running: chalk.yellow('[>]'),
  done: chalk.green('[+]'),
  failed: chalk.red('[x]'),
};

// --- Severity icons ---

export const severityIcon: Record<string, string> = {
  info: chalk.cyan('[i]'),
  warning: chalk.yellow('[!]'),
  critical: chalk.red('[X]'),
  blocker: chalk.magenta('[B]'),
};

// --- Health status ---

export const healthLabel: Record<string, string> = {
  OK: chalk.green('OK'),
  WARN: chalk.yellow('WARN'),
  FAIL: chalk.red('FAIL'),
};

// --- Box drawing (Unicode — supported everywhere) ---

export const box = {
  h: '─',
  v: '│',
  tl: '┌',
  tr: '┐',
  bl: '└',
  br: '┘',
  tee: '├',
  rtee: '┤',
  cross: '┼',
  btee: '┴',
  ttee: '┬',
} as const;

// --- Tree drawing ---

export const tree = {
  branch: '├── ',
  last: '└── ',
  pipe: '│   ',
  space: '    ',
} as const;

// --- Provider context limits (hardcoded known values) ---

export const PROVIDER_LIMITS: Record<string, { short: number; long: number }> = {
  claude: { short: 200_000, long: 680_000 },
  gemini: { short: 128_000, long: 2_000_000 },
  codex: { short: 128_000, long: 128_000 },
  ollama: { short: 8_000, long: 131_000 },
};

// --- Sender colors for conversation panel ---

export function getSenderColor(sender: string): (text: string) => string {
  switch (sender) {
    case 'user': return chalk.green;
    case 'system': return chalk.gray;
    default: return chalk.cyan;  // agents
  }
}

// --- Formatting helpers ---

export function formatTokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n % 1_000_000 === 0 ? 0 : 1)}M`;
  if (n >= 1_000) return `${Math.round(n / 1_000)}k`;
  return String(n);
}

export function formatUptime(startedAt: string | null): string {
  if (!startedAt) return '-';
  const ms = Date.now() - new Date(startedAt).getTime();
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}h${m % 60}m`;
  if (m > 0) return `${m}m${s % 60}s`;
  return `${s}s`;
}

export function progressBar(ratio: number, width: number = 8): string {
  const clamped = Math.max(0, Math.min(1, ratio));
  const filled = Math.round(clamped * width);
  const empty = width - filled;
  return '[' + '#'.repeat(filled) + '-'.repeat(empty) + ']';
}

export function truncate(str: string, maxLen: number): string {
  if (str.length <= maxLen) return str;
  return str.slice(0, maxLen - 1) + '…';
}

export function shortId(id: string): string {
  return id.length > 8 ? id.slice(0, 8) : id;
}

export function formatTimestamp(ts: number): string {
  const d = new Date(ts);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
