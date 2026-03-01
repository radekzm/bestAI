"use strict";
// tui/components/BudgetPanel.tsx — Token budget with progress bar
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const BudgetPanel = ({ tokensUsed, tokensLimit, tokensIn, tokensOut, routing, focused }) => {
    const ratio = tokensLimit > 0 ? tokensUsed / tokensLimit : 0;
    const percent = Math.round(ratio * 100);
    const bar = (0, theme_1.progressBar)(ratio, 8);
    const barColored = percent > 80 ? theme_1.colors.error(bar) : percent > 50 ? theme_1.colors.warning(bar) : theme_1.colors.success(bar);
    const routingParts = Object.entries(routing)
        .map(([vendor, count]) => `${vendor}:${count}`)
        .join(' ');
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", borderStyle: "single", borderColor: focused ? 'cyan' : 'gray', paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null, theme_1.colors.header('BUDGET')),
        react_1.default.createElement(ink_1.Text, null,
            "tokens: ",
            (0, theme_1.formatTokens)(tokensUsed),
            "/",
            (0, theme_1.formatTokens)(tokensLimit),
            " ",
            barColored,
            " ",
            percent,
            "%"),
        react_1.default.createElement(ink_1.Text, null,
            theme_1.colors.label('in:'),
            (0, theme_1.formatTokens)(tokensIn),
            " ",
            theme_1.colors.label('out:'),
            (0, theme_1.formatTokens)(tokensOut)),
        routingParts.length > 0 && (react_1.default.createElement(ink_1.Text, null,
            theme_1.colors.label('routing:'),
            " ",
            theme_1.colors.muted(routingParts)))));
};
exports.default = BudgetPanel;
//# sourceMappingURL=BudgetPanel.js.map