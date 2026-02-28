#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const pkg = require('../package.json');

const args = process.argv.slice(2);
const command = args[0];
const baseDir = path.join(__dirname, '..');

const commands = {
    'init':       path.join(baseDir, 'setup.sh'),
    'setup':      path.join(baseDir, 'setup.sh'),
    'doctor':     path.join(baseDir, 'doctor.sh'),
    'stats':      path.join(baseDir, 'stats.sh'),
    'cockpit':    path.join(baseDir, 'tools', 'cockpit.sh'),
    'test':       path.join(baseDir, 'tests', 'test-hooks.sh'),
    'compliance': path.join(baseDir, 'compliance.sh'),
    'lint':       path.join(baseDir, 'tools', 'hook-lint.sh'),
    'route':      path.join(baseDir, 'tools', 'task-router.sh'),
    'bind-context': path.join(baseDir, 'tools', 'task-memory-binding.sh'),
    'validate-context': path.join(baseDir, 'tools', 'validate-shared-context.sh'),
    'swarm':      path.join(baseDir, 'tools', 'swarm-dispatch.sh'),
    'swarm-lock': path.join(baseDir, 'tools', 'swarm-lock.sh'),
    'shared-context-merge': path.join(baseDir, 'tools', 'shared-context-merge.sh'),
    'merge-context': path.join(baseDir, 'tools', 'shared-context-merge.sh'),
    'permit':     path.join(baseDir, 'tools', 'permit.sh'),
    'generate-rules': path.join(baseDir, 'tools', 'generate-rules.sh'),
    'contract':   path.join(baseDir, 'templates', 'contract-template.json'),
    'sandbox':    path.join(baseDir, 'tools', 'agent-sandbox.sh'),
};

function printHelp() {
    const commandList = Object.keys(commands).sort().join(', ');
    console.log(`bestAI CLI v${pkg.version}`);
    console.log('Usage: bestai <command> [options]');
    console.log(`Commands: ${commandList}`);
}

if (!command || command === '-h' || command === '--help' || command === 'help') {
    printHelp();
    process.exit(0);
}

const scriptPath = commands[command];
if (!scriptPath) {
    console.error(`Unknown command: ${command}`);
    console.error(`Available: ${Object.keys(commands).sort().join(', ')}`);
    process.exit(1);
}

if (!fs.existsSync(scriptPath)) {
    console.error(`Internal Error: Script not found at ${scriptPath}`);
    process.exit(1);
}

// Special case for python scripts
let execCmd = 'bash';
if (scriptPath.endsWith('.py')) {
    execCmd = 'python3';
} else if (scriptPath.endsWith('.json')) {
    execCmd = 'cat';
}

const child = spawn(execCmd, [scriptPath, ...args.slice(1)], { stdio: 'inherit' });
child.on('exit', (code) => {
    process.exit(code);
});
