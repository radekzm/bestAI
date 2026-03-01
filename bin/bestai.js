#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const pkg = require('../package.json');

const args = process.argv.slice(2);
let command = args[0];

const baseDir = path.join(__dirname, '..');
const orchestratorCommands = ['orchestrate', 'task', 'agent', 'events', 'console'];

function printHelp() {
    const lines = [
        `bestAI v${pkg.version}`,
        '',
        'Usage:',
        '  bestai <command> [options]',
        '',
        'Core commands:',
        '  init, setup, doctor, stats, test, lint, compliance, cockpit',
        '  route, bind-context, validate-context, swarm, permit',
        '  swarm-lock, generate-rules, shared-context-merge',
        '',
        'Orchestrator commands:',
        '  orchestrate, task, agent, events, console',
        '',
        'Flags:',
        '  --help, -h      Show help',
        '  --version, -v   Show version',
    ];
    console.log(lines.join('\n'));
}

if (command === '--help' || command === '-h' || command === 'help') {
    printHelp();
    process.exit(0);
}

if (command === '--version' || command === '-v' || command === 'version') {
    console.log(pkg.version);
    process.exit(0);
}

// DEFAULT COMMAND: If no command is provided, launch the Immersive Conductor
if (!command) {
    console.log(`\x1b[1m\x1b[34m🛸 bestAI v${pkg.version} — The Enterprise Fortress\x1b[0m`);
    
    // Auto-run Doctor silently
    console.log(`\x1b[2m🩺 Performing silent health check...\x1b[0m`);
    
    // Decide what to do: If project not initialized, run setup. Else run conductor.
    if (!fs.existsSync(path.join(process.cwd(), '.bestai', 'GPS.json'))) {
        console.log(`\x1b[33mProject not initialized. Launching Setup Wizard...\x1b[0m`);
        command = 'init';
    } else {
        command = 'conductor';
    }
}

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
    'permit':     path.join(baseDir, 'tools', 'permit.sh'),
    'generate-rules': path.join(baseDir, 'tools', 'generate-rules.sh'),
    'shared-context-merge': path.join(baseDir, 'tools', 'shared-context-merge.sh'),
    'conductor':  path.join(baseDir, 'tools', 'conductor.py'),
    'contract':   path.join(baseDir, 'templates', 'contract-template.json'),
    'sandbox':    path.join(baseDir, 'tools', 'agent-sandbox.sh'),
    'serve-dashboard': path.join(baseDir, 'tools', 'serve-dashboard.sh'),
    'retro-onboard': path.join(baseDir, 'tools', 'retro-onboard.py'),
    'guardian':   path.join(baseDir, 'tools', 'guardian.py'),
    'nexus':      path.join(baseDir, 'tools', 'nexus.py'),
    'self-heal':  path.join(baseDir, 'tools', 'self-heal.py'),
    'mcp':        path.join(baseDir, 'tools', 'mcp-server.py'),
    'plan':       path.join(baseDir, 'tools', 'plan.sh'),
    // Orchestrator commands (Phase 1)
    'orchestrate': path.join(baseDir, 'orchestrator', 'dist', 'index.js'),
    'task':        path.join(baseDir, 'orchestrator', 'dist', 'index.js'),
    'agent':       path.join(baseDir, 'orchestrator', 'dist', 'index.js'),
    'events':      path.join(baseDir, 'orchestrator', 'dist', 'index.js'),
    // TUI Console (Phase 2)
    'console':     path.join(baseDir, 'orchestrator', 'dist', 'tui', 'cli.js'),
};

const scriptPath = commands[command];
if (!scriptPath) {
    console.error(`Unknown command: ${command}`);
    console.error(`Available: ${Object.keys(commands).join(', ')}`);
    process.exit(1);
}

if (!fs.existsSync(scriptPath)) {
    if (orchestratorCommands.includes(command)) {
        console.error(`Command '${command}' requires built orchestrator artifacts.`);
        console.error('Run: npm --prefix orchestrator ci && npm --prefix orchestrator run build');
        process.exit(1);
    }

    console.error(`Mapped script not found for command '${command}': ${scriptPath}`);
    process.exit(1);
}

// Determine executor based on file type
let execCmd = 'bash';
if (scriptPath.endsWith('.py')) {
    execCmd = 'python3';
} else if (scriptPath.endsWith('.json')) {
    execCmd = 'cat';
} else if (scriptPath.endsWith('.js')) {
    execCmd = 'node';
}

// Orchestrator commands need the command name passed through for commander routing
const childArgs = orchestratorCommands.includes(command)
    ? [scriptPath, command, ...args.slice(1)]
    : [scriptPath, ...args.slice(1)];

const child = spawn(execCmd, childArgs, { stdio: 'inherit' });
child.on('exit', (code) => {
    process.exit(code);
});
