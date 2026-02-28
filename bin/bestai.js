#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const pkg = require('../package.json');

const args = process.argv.slice(2);
const command = args[0];

if (!command) {
    console.log(`bestAI CLI v${pkg.version}`);
    console.log("Usage: bestai <command> [options]");
    console.log("Commands: init, setup, doctor, stats, cockpit, test, compliance, lint, route, bind-context, validate-context, swarm");
    process.exit(0);
}

const commands = {
    'init':       path.join(__dirname, '..', 'setup.sh'),
    'setup':      path.join(__dirname, '..', 'setup.sh'),
    'doctor':     path.join(__dirname, '..', 'doctor.sh'),
    'stats':      path.join(__dirname, '..', 'stats.sh'),
    'cockpit':    path.join(__dirname, '..', 'tools', 'cockpit.sh'),
    'test':       path.join(__dirname, '..', 'tests', 'test-hooks.sh'),
    'compliance': path.join(__dirname, '..', 'compliance.sh'),
    'lint':       path.join(__dirname, '..', 'tools', 'hook-lint.sh'),
    'route':      path.join(__dirname, '..', 'tools', 'task-router.sh'),
    'bind-context': path.join(__dirname, '..', 'tools', 'task-memory-binding.sh'),
    'validate-context': path.join(__dirname, '..', 'tools', 'validate-shared-context.sh'),
    'swarm':      path.join(__dirname, '..', 'tools', 'swarm-dispatch.sh'),
    'swarm-lock': path.join(__dirname, '..', 'tools', 'swarm-lock.sh'),
};

const scriptPath = commands[command];
if (!scriptPath) {
    console.error(`Unknown command: ${command}`);
    console.error(`Available: ${Object.keys(commands).join(', ')}`);
    process.exit(1);
}

const child = spawn('bash', [scriptPath, ...args.slice(1)], { stdio: 'inherit' });
child.on('exit', (code) => {
    process.exit(code);
});
