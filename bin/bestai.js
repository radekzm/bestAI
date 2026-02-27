#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

const args = process.argv.slice(2);
const command = args[0];

if (!command) {
    console.log("bestAI CLI v5.0");
    console.log("Usage: bestai <command> [options]");
    console.log("Commands: init, setup, doctor, stats, test");
    process.exit(0);
}

let scriptPath = '';
if (command === 'init' || command === 'setup') {
    scriptPath = path.join(__dirname, '..', 'setup.sh');
} else if (command === 'doctor') {
    scriptPath = path.join(__dirname, '..', 'doctor.sh');
} else if (command === 'stats') {
    scriptPath = path.join(__dirname, '..', 'stats.sh');
} else if (command === 'test') {
    scriptPath = path.join(__dirname, '..', 'tests', 'test-hooks.sh');
} else {
    console.error(`Unknown command: ${command}`);
    process.exit(1);
}

const child = spawn('bash', [scriptPath, ...args.slice(1)], { stdio: 'inherit' });
child.on('exit', (code) => {
    process.exit(code);
});
