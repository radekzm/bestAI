"use strict";
// tui/components/ConversationPanel.tsx — Push notifications from agents
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const VISIBLE_ROWS = 5;
const ConversationPanel = ({ notifications, focused, scrollOffset }) => {
    const startIdx = Math.max(0, notifications.length - VISIBLE_ROWS - scrollOffset);
    const visible = notifications.slice(startIdx, startIdx + VISIBLE_ROWS);
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", borderStyle: "single", borderColor: focused ? 'cyan' : 'gray', paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null, theme_1.colors.header('NOTIFICATIONS')),
        visible.length === 0 && react_1.default.createElement(ink_1.Text, null, theme_1.colors.muted('  (no notifications)')),
        visible.map((n) => {
            const ts = (0, theme_1.formatTimestamp)(n.timestamp);
            const icon = theme_1.severityIcon[n.severity] || theme_1.severityIcon.info;
            const agent = n.agent !== '-' ? `@${n.agent}: ` : '';
            return (react_1.default.createElement(ink_1.Text, { key: n.id },
                theme_1.colors.muted(ts),
                " ",
                icon,
                " ",
                theme_1.colors.info(agent),
                (0, theme_1.truncate)(n.message, 30)));
        })));
};
exports.default = ConversationPanel;
//# sourceMappingURL=ConversationPanel.js.map