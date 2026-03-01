#!/usr/bin/env node
"use strict";
// tui/cli.ts — Entry point: check DB, render TUI with Ink
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const App_1 = __importDefault(require("./App"));
const bestaiDir = path_1.default.join(process.cwd(), '.bestai');
const dbPath = path_1.default.join(bestaiDir, 'orchestrator.db');
// Check prerequisites
if (!fs_1.default.existsSync(dbPath)) {
    console.error('No orchestrator database found at', dbPath);
    console.error('Run "bestai orchestrate start" first to initialize the daemon.');
    process.exit(1);
}
// Render the TUI
const { waitUntilExit } = (0, ink_1.render)(react_1.default.createElement(App_1.default, { dbPath }));
waitUntilExit().then(() => {
    process.exit(0);
});
//# sourceMappingURL=cli.js.map