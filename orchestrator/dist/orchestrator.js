"use strict";
// orchestrator/src/orchestrator.ts — Core orchestration logic
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Orchestrator = void 0;
const crypto_1 = __importDefault(require("crypto"));
const bridge_1 = require("./bridge");
const PROCESSING_INTERVAL_MS = 1000;
class Orchestrator {
    constructor(store, bus, agentManager, hierarchy) {
        this.processingTimer = null;
        this.store = store;
        this.bus = bus;
        this.agentManager = agentManager;
        this.hierarchy = hierarchy;
        this.bridge = new bridge_1.BestAIBridge();
    }
    /** Submit a new task to the orchestrator */
    submitTask(description, parentTaskId, dependencies) {
        const task = {
            id: crypto_1.default.randomUUID(),
            description,
            status: 'pending',
            parentTaskId,
            dependencies: dependencies || [],
            createdAt: Date.now(),
            updatedAt: Date.now(),
        };
        this.store.createTask(task);
        this.bus.emit('task:created', task);
        return task;
    }
    /** Process an incoming agent message through the hierarchy */
    processMessage(message) {
        switch (message.type) {
            case 'task_result':
                this.handleTaskResult(message);
                break;
            case 'escalation':
                this.hierarchy.escalate(message);
                break;
            case 'status_update':
                this.handleStatusUpdate(message);
                break;
            case 'task_request':
                this.handleTaskRequest(message);
                break;
            case 'question':
                // Questions from agents are escalated to the user
                this.hierarchy.notifyUser(message.from, message.severity, `Question from agent: ${JSON.stringify(message.payload)}`);
                break;
        }
    }
    /** Push notification to user if severity meets threshold */
    notifyUser(severity, message) {
        this.bus.emit('user:notify', severity, message);
    }
    /** Start the task processing loop */
    startProcessingLoop() {
        this.processingTimer = setInterval(() => {
            this.processTasks();
        }, PROCESSING_INTERVAL_MS);
    }
    /** Stop the task processing loop */
    stopProcessingLoop() {
        if (this.processingTimer) {
            clearInterval(this.processingTimer);
            this.processingTimer = null;
        }
    }
    /** Use the bestAI task router to determine the best approach */
    async routeTask(description) {
        const result = await this.bridge.callTaskRouter(description);
        if (result.success) {
            try {
                return JSON.parse(result.stdout);
            }
            catch {
                return {};
            }
        }
        return {};
    }
    /** Get the bridge for direct access to bestAI tools */
    getBridge() {
        return this.bridge;
    }
    // --- Private ---
    processTasks() {
        const pending = this.store.getPendingTasks();
        for (const task of pending) {
            if (task.status === 'assigned')
                continue; // Already assigned, waiting for agent
            // Check dependencies are met
            if (!this.areDependenciesMet(task))
                continue;
            // Find the best agent for this task
            const role = this.inferRole(task.description);
            const available = this.agentManager.getAvailable(role);
            if (available.length === 0)
                continue;
            // Assign to first available agent
            const agent = available[0];
            this.store.assignTask(task.id, agent.id);
            this.store.updateAgentStatus(agent.id, 'working');
            this.bus.emit('task:assigned', task.id, agent.id);
            this.bus.emit('agent:status', agent.id, 'working');
            // Send task to agent via hierarchy
            const message = {
                id: crypto_1.default.randomUUID(),
                from: 'orchestrator',
                to: agent.id,
                type: 'task_request',
                severity: 'info',
                payload: { taskId: task.id, description: task.description },
                parentTaskId: task.parentTaskId,
                timestamp: Date.now(),
            };
            this.hierarchy.send(message);
        }
    }
    areDependenciesMet(task) {
        if (task.dependencies.length === 0)
            return true;
        for (const depId of task.dependencies) {
            const dep = this.store.getTask(depId);
            if (!dep || dep.status !== 'done')
                return false;
        }
        return true;
    }
    inferRole(description) {
        const lower = description.toLowerCase();
        if (lower.includes('security') || lower.includes('guard') || lower.includes('audit')) {
            return 'guardian';
        }
        if (lower.includes('plan') || lower.includes('design') || lower.includes('architect')) {
            return 'planner';
        }
        if (lower.includes('search') || lower.includes('find') || lower.includes('research')) {
            return 'knowledge';
        }
        if (lower.includes('execute') || lower.includes('run') || lower.includes('build') || lower.includes('implement')) {
            return 'executor';
        }
        return 'assistant';
    }
    handleTaskResult(message) {
        const payload = message.payload;
        if (!payload.taskId)
            return;
        this.store.updateTaskStatus(payload.taskId, 'done', payload.result);
        this.store.updateAgentStatus(message.from, 'idle');
        this.bus.emit('task:completed', payload.taskId, payload.result);
        this.bus.emit('agent:status', message.from, 'idle');
    }
    handleStatusUpdate(message) {
        const payload = message.payload;
        if (payload.taskId && payload.percent !== undefined) {
            this.bus.emit('task:progress', payload.taskId, payload.percent, payload.summary || '');
        }
    }
    handleTaskRequest(message) {
        // An agent is requesting a sub-task to be created
        const payload = message.payload;
        if (payload.description) {
            this.submitTask(payload.description, payload.parentTaskId);
        }
    }
}
exports.Orchestrator = Orchestrator;
//# sourceMappingURL=orchestrator.js.map