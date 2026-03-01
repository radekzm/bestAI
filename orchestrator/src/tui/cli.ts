#!/usr/bin/env node
// tui/cli.ts — Entry point: check DB, render TUI with Ink

import React from 'react';
import { render } from 'ink';
import fs from 'fs';
import path from 'path';
import App from './App';

const bestaiDir = path.join(process.cwd(), '.bestai');
const dbPath = path.join(bestaiDir, 'orchestrator.db');

// Check prerequisites
if (!fs.existsSync(dbPath)) {
  console.error('No orchestrator database found at', dbPath);
  console.error('Run "bestai orchestrate start" first to initialize the daemon.');
  process.exit(1);
}

// Render the TUI
const { waitUntilExit } = render(React.createElement(App, { dbPath }));

waitUntilExit().then(() => {
  process.exit(0);
});
