"use strict";
// orchestrator/src/agent-manager.ts — Agent lifecycle management
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentManager = void 0;
const child_process_1 = require("child_process");
const HEARTBEAT_TIMEOUT_MS = 30000;
const MAX_RESTARTS = 3;
class AgentManager {
    constructor(store, bus) {
        this.running = new Map();
        this.heartbeatInterval = null;
        this.store = store;
        this.bus = bus;
    }
    /** Register an agent in the store and emit event */
    register(config) {
        this.store.registerAgent(config);
        this.bus.emit('agent:registered', config);
    }
    /** Spawn an agent as a child process */
    spawn(agentId, scriptPath) {
        const config = this.store.getAgent(agentId);
        if (!config)
            return false;
        const existing = this.running.get(agentId);
        if (existing?.process && !existing.process.killed) {
            return false; // already running
        }
        let child = null;
        if (scriptPath) {
            child = (0, child_process_1.fork)(scriptPath, ['--agent-id', agentId], {
                stdio: ['pipe', 'pipe', 'pipe', 'ipc'],
                env: {
                    ...process.env,
                    BESTAI_AGENT_ID: agentId,
                    BESTAI_AGENT_ROLE: config.role,
                    BESTAI_AGENT_LEVEL: String(config.level),
                },
            });
            child.on('exit', (code) => {
                this.handleAgentExit(agentId, code);
            });
            child.on('message', (msg) => {
                this.handleAgentMessage(agentId, msg);
            });
        }
        this.running.set(agentId, {
            config,
            process: child,
            lastHeartbeat: Date.now(),
            restartCount: existing?.restartCount ?? 0,
        });
        this.store.updateAgentStatus(agentId, 'idle');
        this.bus.emit('agent:status', agentId, 'idle');
        return true;
    }
    /** Graceful kill: send shutdown message, then SIGTERM after timeout */
    async kill(agentId) {
        const agent = this.running.get(agentId);
        if (!agent?.process || agent.process.killed) {
            this.running.delete(agentId);
            this.store.updateAgentStatus(agentId, 'stopped');
            this.bus.emit('agent:status', agentId, 'stopped');
            return;
        }
        // Send graceful shutdown via IPC
        try {
            agent.process.send({ type: 'shutdown' });
        }
        catch {
            // IPC may already be closed
        }
        // Wait 5s then SIGTERM
        await new Promise((resolve) => {
            const timeout = setTimeout(() => {
                if (agent.process && !agent.process.killed) {
                    agent.process.kill('SIGTERM');
                }
                resolve();
            }, 5000);
            agent.process.once('exit', () => {
                clearTimeout(timeout);
                resolve();
            });
        });
        this.running.delete(agentId);
        this.store.updateAgentStatus(agentId, 'stopped');
        this.bus.emit('agent:status', agentId, 'stopped');
    }
    /** Update heartbeat timestamp */
    heartbeat(agentId) {
        const agent = this.running.get(agentId);
        if (agent) {
            agent.lastHeartbeat = Date.now();
        }
    }
    /** Find idle agents matching a role */
    getAvailable(role) {
        if (role) {
            return this.store.getAgentsByRole(role);
        }
        return this.store.getAllAgents().filter((a) => a.status === 'idle');
    }
    /** Get all registered agents */
    getAll() {
        return this.store.getAllAgents();
    }
    /** Check if an agent is currently running */
    isRunning(agentId) {
        const agent = this.running.get(agentId);
        return !!agent?.process && !agent.process.killed;
    }
    /** Start the heartbeat monitor */
    startMonitor() {
        this.heartbeatInterval = setInterval(() => {
            this.checkHeartbeats();
        }, HEARTBEAT_TIMEOUT_MS / 2);
    }
    /** Stop the heartbeat monitor */
    stopMonitor() {
        if (this.heartbeatInterval) {
            clearInterval(this.heartbeatInterval);
            this.heartbeatInterval = null;
        }
    }
    /** Gracefully shutdown all running agents */
    async shutdownAll() {
        this.stopMonitor();
        const ids = Array.from(this.running.keys());
        await Promise.all(ids.map((id) => this.kill(id)));
    }
    /** Send a message to an agent via IPC */
    sendToAgent(agentId, message) {
        const agent = this.running.get(agentId);
        if (!agent?.process || agent.process.killed)
            return false;
        try {
            agent.process.send(JSON.parse(JSON.stringify(message)));
            return true;
        }
        catch {
            return false;
        }
    }
    // --- Private ---
    handleAgentExit(agentId, code) {
        const agent = this.running.get(agentId);
        if (!agent)
            return;
        if (code !== 0 && agent.restartCount < MAX_RESTARTS) {
            // Auto-restart on crash
            agent.restartCount++;
            agent.process = null;
            this.store.updateAgentStatus(agentId, 'error');
            this.bus.emit('agent:status', agentId, 'error');
            this.bus.emit('user:notify', 'warning', `Agent ${agentId} crashed (exit ${code}), restarting (${agent.restartCount}/${MAX_RESTARTS})`);
            // Restart after a brief delay
            setTimeout(() => this.spawn(agentId), 1000);
        }
        else {
            this.running.delete(agentId);
            this.store.updateAgentStatus(agentId, code === 0 ? 'stopped' : 'error');
            this.bus.emit('agent:status', agentId, code === 0 ? 'stopped' : 'error');
            if (code !== 0) {
                this.bus.emit('user:notify', 'critical', `Agent ${agentId} crashed (exit ${code}), max restarts exceeded`);
            }
        }
    }
    handleAgentMessage(agentId, msg) {
        if (!msg || typeof msg !== 'object')
            return;
        const message = msg;
        if (message.type === 'heartbeat') {
            this.heartbeat(agentId);
        }
        else if (message.type === 'status_update') {
            const status = message.status;
            this.store.updateAgentStatus(agentId, status);
            this.bus.emit('agent:status', agentId, status);
        }
    }
    checkHeartbeats() {
        const now = Date.now();
        for (const [id, agent] of this.running) {
            if (agent.process && !agent.process.killed) {
                if (now - agent.lastHeartbeat > HEARTBEAT_TIMEOUT_MS) {
                    this.bus.emit('user:notify', 'warning', `Agent ${id} heartbeat timeout`);
                    this.store.updateAgentStatus(id, 'error');
                    this.bus.emit('agent:status', id, 'error');
                }
            }
        }
    }
}
exports.AgentManager = AgentManager;
//# sourceMappingURL=agent-manager.js.map