"use strict";
// orchestrator/src/daemon.ts — Daemon lifecycle management
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Daemon = void 0;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const state_store_1 = require("./state-store");
const event_bus_1 = require("./event-bus");
const agent_manager_1 = require("./agent-manager");
const agent_hierarchy_1 = require("./agent-hierarchy");
const orchestrator_1 = require("./orchestrator");
const CHECKPOINT_INTERVAL_MS = 30000;
const VERSION = '1.0.0';
class Daemon {
    constructor(workDir) {
        this.store = null;
        this.bus = null;
        this.agentManager = null;
        this.hierarchy = null;
        this.orchestrator = null;
        this.checkpointTimer = null;
        const base = workDir || process.cwd();
        const bestaiDir = path_1.default.join(base, '.bestai');
        this.paths = {
            bestaiDir,
            pidFile: path_1.default.join(bestaiDir, 'daemon.pid'),
            dbFile: path_1.default.join(bestaiDir, 'orchestrator.db'),
        };
    }
    /** Start the daemon */
    async start() {
        // Check for existing daemon
        if (this.isRunning()) {
            const pid = this.readPid();
            console.error(`Daemon already running (PID ${pid})`);
            process.exit(1);
        }
        fs_1.default.mkdirSync(this.paths.bestaiDir, { recursive: true });
        // Initialize components
        this.store = new state_store_1.StateStore(this.paths.dbFile);
        this.bus = event_bus_1.OrchestratorEventBus.create(this.store, this.paths.bestaiDir);
        this.agentManager = new agent_manager_1.AgentManager(this.store, this.bus);
        this.hierarchy = new agent_hierarchy_1.AgentHierarchy(this.store, this.bus, this.agentManager);
        this.orchestrator = new orchestrator_1.Orchestrator(this.store, this.bus, this.agentManager, this.hierarchy);
        // Write PID
        fs_1.default.writeFileSync(this.paths.pidFile, String(process.pid));
        // Store daemon state
        this.store.setDaemonState('pid', String(process.pid));
        this.store.setDaemonState('startedAt', new Date().toISOString());
        this.store.setDaemonState('version', VERSION);
        // Register built-in agents
        this.registerBuiltinAgents();
        // Recovery: handle tasks that were in-flight when daemon died
        this.recoverIncompleteTasks();
        // Start heartbeat monitor
        this.agentManager.startMonitor();
        // Start task processing loop
        this.orchestrator.startProcessingLoop();
        // Start checkpoint timer
        this.checkpointTimer = setInterval(() => {
            this.checkpoint();
        }, CHECKPOINT_INTERVAL_MS);
        // Handle signals
        process.on('SIGTERM', () => this.stop());
        process.on('SIGINT', () => this.stop());
        this.bus.emit('daemon:started');
        console.log(`Daemon started (PID ${process.pid})`);
    }
    /** Stop the daemon gracefully */
    async stop() {
        console.log('Shutting down daemon...');
        if (this.checkpointTimer) {
            clearInterval(this.checkpointTimer);
            this.checkpointTimer = null;
        }
        if (this.orchestrator) {
            this.orchestrator.stopProcessingLoop();
        }
        if (this.agentManager) {
            await this.agentManager.shutdownAll();
        }
        this.checkpoint();
        if (this.bus) {
            this.bus.emit('daemon:stopped');
        }
        // Remove PID file
        try {
            fs_1.default.unlinkSync(this.paths.pidFile);
        }
        catch {
            // May already be gone
        }
        if (this.store) {
            this.store.clearDaemonState();
            this.store.close();
        }
        event_bus_1.OrchestratorEventBus.reset();
        console.log('Daemon stopped');
    }
    /** Get daemon status */
    status() {
        const running = this.isRunning();
        const pid = this.readPid();
        if (!running) {
            return {
                running: false,
                pid: null,
                startedAt: null,
                version: null,
                agents: [],
                pendingTasks: 0,
                lastCheckpoint: null,
            };
        }
        // Read from DB
        const store = new state_store_1.StateStore(this.paths.dbFile);
        const agents = store.getAllAgents();
        const pending = store.getPendingTasks();
        const startedAt = store.getDaemonState('startedAt');
        const version = store.getDaemonState('version');
        const lastCheckpoint = store.getDaemonState('lastCheckpoint');
        store.close();
        return {
            running: true,
            pid,
            startedAt,
            version,
            agents,
            pendingTasks: pending.length,
            lastCheckpoint,
        };
    }
    /** Check if daemon is currently running */
    isRunning() {
        const pid = this.readPid();
        if (!pid)
            return false;
        try {
            // Signal 0 checks if process exists without sending a signal
            process.kill(pid, 0);
            return true;
        }
        catch {
            // Process not found — stale PID file
            try {
                fs_1.default.unlinkSync(this.paths.pidFile);
            }
            catch { /* ignore */ }
            return false;
        }
    }
    // --- Private ---
    readPid() {
        try {
            const content = fs_1.default.readFileSync(this.paths.pidFile, 'utf-8').trim();
            const pid = parseInt(content, 10);
            return isNaN(pid) ? null : pid;
        }
        catch {
            return null;
        }
    }
    checkpoint() {
        if (!this.store)
            return;
        this.store.setDaemonState('lastCheckpoint', new Date().toISOString());
    }
    registerBuiltinAgents() {
        if (!this.agentManager)
            return;
        const builtins = [
            {
                id: 'main-assistant',
                name: 'Main Assistant',
                level: 0,
                role: 'assistant',
                maxConcurrentTasks: 3,
            },
            {
                id: 'guardian',
                name: 'Guardian',
                level: 1,
                role: 'guardian',
                parentId: 'main-assistant',
                maxConcurrentTasks: 2,
            },
            {
                id: 'planner',
                name: 'Planner',
                level: 1,
                role: 'planner',
                parentId: 'main-assistant',
                maxConcurrentTasks: 2,
            },
            {
                id: 'knowledge',
                name: 'Knowledge',
                level: 1,
                role: 'knowledge',
                parentId: 'main-assistant',
                maxConcurrentTasks: 2,
            },
            {
                id: 'executor-1',
                name: 'Executor 1',
                level: 2,
                role: 'executor',
                parentId: 'planner',
                maxConcurrentTasks: 1,
            },
        ];
        for (const agent of builtins) {
            this.agentManager.register(agent);
        }
    }
    recoverIncompleteTasks() {
        if (!this.store || !this.bus)
            return;
        const incomplete = this.store.getIncompleteTasks();
        for (const task of incomplete) {
            if (task.status === 'running') {
                // Running tasks from a dead daemon → mark failed
                this.store.updateTaskStatus(task.id, 'failed', { error: 'Daemon restart recovery' });
                this.bus.emit('task:failed', task.id, 'Daemon restart recovery — task was running when daemon died');
            }
            // pending/assigned tasks stay as-is for the queue to pick up
        }
        if (incomplete.length > 0) {
            const failed = incomplete.filter((t) => t.status === 'running').length;
            const kept = incomplete.length - failed;
            this.bus.emit('user:notify', 'info', `Recovery: ${failed} running tasks marked failed, ${kept} pending tasks re-queued`);
        }
    }
}
exports.Daemon = Daemon;
//# sourceMappingURL=daemon.js.map