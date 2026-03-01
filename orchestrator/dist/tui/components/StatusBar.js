"use strict";
// tui/components/StatusBar.tsx — Top bar: daemon status, agents, tasks, health
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
const StatusBar = ({ daemon, totalAgents, totalTasks, health }) => {
    const dot = daemon.running ? theme_1.statusDot.idle : theme_1.statusDot.stopped;
    const pid = daemon.pid ? `PID ${daemon.pid}` : 'no PID';
    const uptime = (0, theme_1.formatUptime)(daemon.startedAt);
    const hLabel = theme_1.healthLabel[health] || theme_1.healthLabel.OK;
    return (react_1.default.createElement(ink_1.Box, { borderStyle: "single", borderColor: "cyan", paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null, theme_1.colors.header(' bestAI Orchestrator ')),
        react_1.default.createElement(ink_1.Text, null,
            " ",
            dot,
            " daemon ",
            pid,
            " up ",
            uptime),
        react_1.default.createElement(ink_1.Text, null,
            " ",
            theme_1.colors.muted('│'),
            " agents: ",
            theme_1.colors.value(String(totalAgents))),
        react_1.default.createElement(ink_1.Text, null,
            " ",
            theme_1.colors.muted('│'),
            " tasks: ",
            theme_1.colors.value(String(totalTasks))),
        react_1.default.createElement(ink_1.Text, null,
            " ",
            theme_1.colors.muted('│'),
            " health: ",
            hLabel)));
};
exports.default = StatusBar;
//# sourceMappingURL=StatusBar.js.map