"use strict";
// tui/components/HelpBar.tsx — Bottom keyboard shortcuts bar
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const HelpBar = ({ activePanel }) => {
    return (react_1.default.createElement(ink_1.Box, { borderStyle: "single", borderColor: "gray", paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null,
            theme_1.colors.info('Tab'),
            " panel ",
            theme_1.colors.muted('│'),
            " ",
            theme_1.colors.info('1-4'),
            " jump ",
            theme_1.colors.muted('│'),
            " ",
            theme_1.colors.info('Up/Down'),
            " scroll ",
            theme_1.colors.muted('│'),
            " ",
            theme_1.colors.info('q'),
            " quit ",
            theme_1.colors.muted('│'),
            " active: ",
            theme_1.colors.bold(activePanel))));
};
exports.default = HelpBar;
//# sourceMappingURL=HelpBar.js.map