"use strict";
// tui/components/TaskList.tsx — Scrollable task queue with status symbols
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const VISIBLE_ROWS = 5;
const TaskList = ({ tasks, focused, scrollOffset, selectedIndex }) => {
    const visible = tasks.slice(scrollOffset, scrollOffset + VISIBLE_ROWS);
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", borderStyle: "single", borderColor: focused ? 'cyan' : 'gray', paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null,
            theme_1.colors.header('TASKS'),
            " ",
            theme_1.colors.muted(`(${tasks.length} total)`)),
        visible.length === 0 && react_1.default.createElement(ink_1.Text, null, theme_1.colors.muted('  (no tasks)')),
        visible.map((t, i) => {
            const idx = scrollOffset + i;
            const sym = theme_1.taskSymbol[t.status] || theme_1.taskSymbol.pending;
            const agent = t.assignedAgent ? ` → ${t.assignedAgent}` : '';
            const line = `${sym} ${(0, theme_1.shortId)(t.id)} ${(0, theme_1.truncate)(t.description, 22)}${agent}`;
            const isSelected = focused && idx === selectedIndex;
            return (react_1.default.createElement(ink_1.Text, { key: t.id }, isSelected ? theme_1.colors.inverse(line) : line));
        })));
};
exports.default = TaskList;
//# sourceMappingURL=TaskList.js.map