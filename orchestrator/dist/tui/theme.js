"use strict";
// tui/theme.ts — ANSI-16 safe color palette + symbols
// Only named colors — works on PuTTY, macOS Terminal.app, Linux, SSH
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PROVIDER_LIMITS = exports.tree = exports.box = exports.healthLabel = exports.severityIcon = exports.taskSymbol = exports.statusDot = exports.colors = void 0;
exports.formatTokens = formatTokens;
exports.formatUptime = formatUptime;
exports.progressBar = progressBar;
exports.truncate = truncate;
exports.shortId = shortId;
exports.formatTimestamp = formatTimestamp;
const chalk_1 = __importDefault(require("chalk"));
// --- Colors (chalk@4 named colors = ANSI-16) ---
exports.colors = {
    success: chalk_1.default.green,
    error: chalk_1.default.red,
    warning: chalk_1.default.yellow,
    info: chalk_1.default.cyan,
    special: chalk_1.default.magenta,
    text: chalk_1.default.white,
    muted: chalk_1.default.gray,
    bold: chalk_1.default.bold,
    dim: chalk_1.default.dim,
    inverse: chalk_1.default.inverse,
    // Composite
    header: chalk_1.default.bold.cyan,
    label: chalk_1.default.gray,
    value: chalk_1.default.white,
    border: chalk_1.default.gray,
    borderFocused: chalk_1.default.cyan,
};
// --- Agent status dots ---
exports.statusDot = {
    idle: chalk_1.default.green('●'),
    working: chalk_1.default.yellow('●'),
    waiting: chalk_1.default.cyan('●'),
    error: chalk_1.default.red('●'),
    stopped: chalk_1.default.gray('●'),
};
// --- Task status symbols ---
exports.taskSymbol = {
    pending: '[ ]',
    assigned: chalk_1.default.yellow('[~]'),
    running: chalk_1.default.yellow('[>]'),
    done: chalk_1.default.green('[+]'),
    failed: chalk_1.default.red('[x]'),
};
// --- Severity icons ---
exports.severityIcon = {
    info: chalk_1.default.cyan('[i]'),
    warning: chalk_1.default.yellow('[!]'),
    critical: chalk_1.default.red('[X]'),
    blocker: chalk_1.default.magenta('[B]'),
};
// --- Health status ---
exports.healthLabel = {
    OK: chalk_1.default.green('OK'),
    WARN: chalk_1.default.yellow('WARN'),
    FAIL: chalk_1.default.red('FAIL'),
};
// --- Box drawing (Unicode — supported everywhere) ---
exports.box = {
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
};
// --- Tree drawing ---
exports.tree = {
    branch: '├── ',
    last: '└── ',
    pipe: '│   ',
    space: '    ',
};
// --- Provider context limits (hardcoded known values) ---
exports.PROVIDER_LIMITS = {
    claude: { short: 200000, long: 680000 },
    gemini: { short: 128000, long: 2000000 },
    codex: { short: 128000, long: 128000 },
    ollama: { short: 8000, long: 131000 },
};
// --- Formatting helpers ---
function formatTokens(n) {
    if (n >= 1000000)
        return `${(n / 1000000).toFixed(n % 1000000 === 0 ? 0 : 1)}M`;
    if (n >= 1000)
        return `${Math.round(n / 1000)}k`;
    return String(n);
}
function formatUptime(startedAt) {
    if (!startedAt)
        return '-';
    const ms = Date.now() - new Date(startedAt).getTime();
    const s = Math.floor(ms / 1000);
    const m = Math.floor(s / 60);
    const h = Math.floor(m / 60);
    if (h > 0)
        return `${h}h${m % 60}m`;
    if (m > 0)
        return `${m}m${s % 60}s`;
    return `${s}s`;
}
function progressBar(ratio, width = 8) {
    const clamped = Math.max(0, Math.min(1, ratio));
    const filled = Math.round(clamped * width);
    const empty = width - filled;
    return '[' + '#'.repeat(filled) + '-'.repeat(empty) + ']';
}
function truncate(str, maxLen) {
    if (str.length <= maxLen)
        return str;
    return str.slice(0, maxLen - 1) + '…';
}
function shortId(id) {
    return id.length > 8 ? id.slice(0, 8) : id;
}
function formatTimestamp(ts) {
    const d = new Date(ts);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
//# sourceMappingURL=theme.js.map