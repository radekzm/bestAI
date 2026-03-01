"use strict";
// tui/components/LimitsPanel.tsx — Multi-provider context limits table
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const LimitsPanel = ({ providerUsed, focused }) => {
    const providers = Object.keys(theme_1.PROVIDER_LIMITS);
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", borderStyle: "single", borderColor: focused ? 'cyan' : 'gray', paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null, theme_1.colors.header('CONTEXT LIMITS')),
        react_1.default.createElement(ink_1.Text, null,
            theme_1.colors.label('Provider'),
            "  ",
            theme_1.colors.label('Short'),
            "  ",
            theme_1.colors.label('Long'),
            "    ",
            theme_1.colors.label('Used')),
        providers.map((p) => {
            const limits = theme_1.PROVIDER_LIMITS[p];
            const used = providerUsed[p] || 0;
            const name = p.padEnd(9);
            const short = (0, theme_1.formatTokens)(limits.short).padStart(5);
            const long = (0, theme_1.formatTokens)(limits.long).padStart(5);
            const usedStr = (0, theme_1.formatTokens)(used).padStart(5);
            return (react_1.default.createElement(ink_1.Text, { key: p },
                theme_1.colors.info(name),
                " ",
                theme_1.colors.value(short),
                "  ",
                theme_1.colors.value(long),
                "  ",
                used > 0 ? theme_1.colors.warning(usedStr) : theme_1.colors.muted(usedStr)));
        })));
};
exports.default = LimitsPanel;
//# sourceMappingURL=LimitsPanel.js.map