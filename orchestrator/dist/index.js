#!/usr/bin/env node
"use strict";
// orchestrator/src/index.ts — CLI entry point
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const commander_1 = require("commander");
const daemon_1 = require("./daemon");
const state_store_1 = require("./state-store");
const event_bus_1 = require("./event-bus");
const agent_manager_1 = require("./agent-manager");
const agent_hierarchy_1 = require("./agent-hierarchy");
const orchestrator_1 = require("./orchestrator");
const path_1 = __importDefault(require("path"));
const program = new commander_1.Command();
program
    .name('bestai-orchestrator')
    .description('bestAI Orchestrator — daemon, agent hierarchy, event bus')
    .version('1.0.0');
// --- Orchestrate commands ---
const orchestrate = program
    .command('orchestrate')
    .description('Daemon lifecycle management');
orchestrate
    .command('start')
    .description('Start the orchestrator daemon')
    .action(async () => {
    const daemon = new daemon_1.Daemon();
    await daemon.start();
    // Keep process alive
    process.stdin.resume();
});
orchestrate
    .command('stop')
    .description('Stop the orchestrator daemon')
    .action(() => {
    const daemon = new daemon_1.Daemon();
    const status = daemon.status();
    if (!status.running || !status.pid) {
        console.log('Daemon is not running');
        process.exit(0);
    }
    try {
        process.kill(status.pid, 'SIGTERM');
        console.log(`Sent SIGTERM to daemon (PID ${status.pid})`);
    }
    catch (err) {
        console.error(`Failed to stop daemon: ${err}`);
        process.exit(1);
    }
});
orchestrate
    .command('status')
    .description('Show daemon and agent status')
    .action(() => {
    const daemon = new daemon_1.Daemon();
    const info = daemon.status();
    if (!info.running) {
        console.log('Daemon: NOT RUNNING');
        return;
    }
    console.log(`Daemon: RUNNING (PID ${info.pid})`);
    console.log(`Started: ${info.startedAt}`);
    console.log(`Version: ${info.version}`);
    console.log(`Last checkpoint: ${info.lastCheckpoint || 'none'}`);
    console.log(`Pending tasks: ${info.pendingTasks}`);
    console.log('');
    console.log('Agents:');
    if (info.agents.length === 0) {
        console.log('  (none registered)');
    }
    else {
        for (const agent of info.agents) {
            const parent = agent.parentId ? ` (parent: ${agent.parentId})` : '';
            console.log(`  [L${agent.level}] ${agent.id} — ${agent.role} — ${agent.status || 'idle'}${parent}`);
        }
    }
});
// --- Task commands ---
const task = program
    .command('task')
    .description('Task management');
task
    .command('submit <description>')
    .description('Submit a new task to the orchestrator')
    .option('-p, --parent <taskId>', 'Parent task ID')
    .option('-d, --dep <taskIds...>', 'Dependency task IDs')
    .action((description, opts) => {
    const dbPath = path_1.default.join(process.cwd(), '.bestai', 'orchestrator.db');
    const store = new state_store_1.StateStore(dbPath);
    const bus = event_bus_1.OrchestratorEventBus.create(store);
    const agentManager = new agent_manager_1.AgentManager(store, bus);
    const hierarchy = new agent_hierarchy_1.AgentHierarchy(store, bus, agentManager);
    const orch = new orchestrator_1.Orchestrator(store, bus, agentManager, hierarchy);
    const t = orch.submitTask(description, opts.parent, opts.dep);
    console.log(`Task created: ${t.id}`);
    console.log(`  Description: ${t.description}`);
    console.log(`  Status: ${t.status}`);
    store.close();
    event_bus_1.OrchestratorEventBus.reset();
});
task
    .command('list')
    .description('List all tasks')
    .option('-s, --status <status>', 'Filter by status')
    .action((opts) => {
    const dbPath = path_1.default.join(process.cwd(), '.bestai', 'orchestrator.db');
    const store = new state_store_1.StateStore(dbPath);
    const tasks = store.getAllTasks();
    store.close();
    const filtered = opts.status
        ? tasks.filter((t) => t.status === opts.status)
        : tasks;
    if (filtered.length === 0) {
        console.log('No tasks found');
        return;
    }
    for (const t of filtered) {
        const agent = t.assignedAgent ? ` → ${t.assignedAgent}` : '';
        console.log(`  ${t.id}  [${t.status}]${agent}  ${t.description}`);
    }
});
// --- Agent commands ---
const agent = program
    .command('agent')
    .description('Agent management');
agent
    .command('list')
    .description('List registered agents')
    .action(() => {
    const dbPath = path_1.default.join(process.cwd(), '.bestai', 'orchestrator.db');
    const store = new state_store_1.StateStore(dbPath);
    const agents = store.getAllAgents();
    store.close();
    if (agents.length === 0) {
        console.log('No agents registered');
        return;
    }
    console.log('Registered agents:');
    for (const a of agents) {
        const parent = a.parentId ? ` (parent: ${a.parentId})` : ' (root)';
        console.log(`  [L${a.level}] ${a.id} — ${a.role} — ${a.status || 'idle'}${parent}`);
    }
});
agent
    .command('spawn <agentId>')
    .description('Manually spawn an agent process')
    .option('-s, --script <path>', 'Script path for the agent')
    .action((agentId, opts) => {
    const dbPath = path_1.default.join(process.cwd(), '.bestai', 'orchestrator.db');
    const store = new state_store_1.StateStore(dbPath);
    const bus = event_bus_1.OrchestratorEventBus.create(store);
    const manager = new agent_manager_1.AgentManager(store, bus);
    const ok = manager.spawn(agentId, opts.script);
    console.log(ok ? `Agent ${agentId} spawned` : `Failed to spawn agent ${agentId}`);
    store.close();
    event_bus_1.OrchestratorEventBus.reset();
});
// --- Events command ---
program
    .command('events')
    .description('Stream events (tail -f style)')
    .option('-n, --lines <count>', 'Number of recent events to show', '20')
    .option('-f, --follow', 'Follow new events')
    .action((opts) => {
    const dbPath = path_1.default.join(process.cwd(), '.bestai', 'orchestrator.db');
    const store = new state_store_1.StateStore(dbPath);
    const limit = parseInt(opts.lines, 10) || 20;
    const events = store.getRecentEvents(limit);
    // Print in chronological order
    events.reverse().forEach((e) => {
        const ts = new Date(e.created_at).toISOString();
        const agent = e.agent_id || '-';
        const task = e.task_id || '-';
        console.log(`${ts}  [${e.severity}]  ${e.type}  agent=${agent}  task=${task}`);
    });
    if (opts.follow) {
        let lastId = events.length > 0 ? events[events.length - 1].id : 0;
        const interval = setInterval(() => {
            try {
                const newEvents = store.getEventsSince(lastId);
                for (const e of newEvents) {
                    const ts = new Date(e.created_at).toISOString();
                    const agent = e.agent_id || '-';
                    const task = e.task_id || '-';
                    console.log(`${ts}  [${e.severity}]  ${e.type}  agent=${agent}  task=${task}`);
                    lastId = e.id;
                }
            }
            catch {
                clearInterval(interval);
                store.close();
                process.exit(0);
            }
        }, 1000);
        process.on('SIGINT', () => {
            clearInterval(interval);
            store.close();
            process.exit(0);
        });
    }
    else {
        store.close();
    }
});
program.parse();
//# sourceMappingURL=index.js.map