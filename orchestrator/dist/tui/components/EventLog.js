"use strict";
// tui/components/EventLog.tsx — Scrollable event stream
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const VISIBLE_ROWS = 5;
const EventLog = ({ events, totalEvents, focused, scrollOffset }) => {
    // Show most recent events, scrollable
    const startIdx = Math.max(0, events.length - VISIBLE_ROWS - scrollOffset);
    const visible = events.slice(startIdx, startIdx + VISIBLE_ROWS);
    const rangeStart = startIdx + 1;
    const rangeEnd = startIdx + visible.length;
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", borderStyle: "single", borderColor: focused ? 'cyan' : 'gray', paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null,
            theme_1.colors.header('EVENTS'),
            " ",
            theme_1.colors.muted(`(${totalEvents} total, ${rangeStart}-${rangeEnd})`)),
        visible.length === 0 && react_1.default.createElement(ink_1.Text, null, theme_1.colors.muted('  (no events)')),
        visible.map((e) => {
            const ts = (0, theme_1.formatTimestamp)(e.created_at);
            const icon = theme_1.severityIcon[e.severity] || theme_1.severityIcon.info;
            const agent = e.agent_id ? ` @${e.agent_id}` : '';
            const task = e.task_id ? ` #${e.task_id.slice(0, 4)}` : '';
            return (react_1.default.createElement(ink_1.Text, { key: e.id },
                theme_1.colors.muted(ts),
                " ",
                icon,
                " ",
                e.type,
                agent,
                task));
        })));
};
exports.default = EventLog;
//# sourceMappingURL=EventLog.js.map