"use strict";
// orchestrator/src/event-bus.ts — Typed event bus with SQLite persistence
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrchestratorEventBus = void 0;
const events_1 = require("events");
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
/**
 * Typed event bus with:
 * - Type-safe emit/on via OrchestratorEvents
 * - Every event persisted to SQLite events table
 * - JSONL bridge for backward compat with hooks/lib-event-bus.sh
 * - Replay from SQLite for crash recovery
 */
class OrchestratorEventBus {
    constructor(store, bestaiDir) {
        this.emitter = new events_1.EventEmitter();
        this.emitter.setMaxListeners(50);
        this.store = store;
        const dir = bestaiDir || path_1.default.join(process.cwd(), '.bestai');
        fs_1.default.mkdirSync(dir, { recursive: true });
        this.jsonlPath = path_1.default.join(dir, 'event_bus.jsonl');
    }
    static create(store, bestaiDir) {
        if (!OrchestratorEventBus.instance) {
            OrchestratorEventBus.instance = new OrchestratorEventBus(store, bestaiDir);
        }
        return OrchestratorEventBus.instance;
    }
    static getInstance() {
        return OrchestratorEventBus.instance;
    }
    static reset() {
        OrchestratorEventBus.instance = null;
    }
    /** Type-safe event emission — persists to SQLite + JSONL, then emits in-memory */
    emit(event, ...args) {
        // Persist to SQLite
        const severity = this.inferSeverity(event, args);
        const agentId = this.inferAgentId(event, args);
        const taskId = this.inferTaskId(event, args);
        this.store.insertEvent(event, severity, agentId, taskId, args);
        // Bridge to JSONL for backward compat with bash hooks
        this.appendJsonl(event, severity, agentId, args);
        // In-memory emit
        this.emitter.emit(event, ...args);
    }
    /** Type-safe event subscription */
    on(event, listener) {
        this.emitter.on(event, listener);
    }
    /** One-time listener */
    once(event, listener) {
        this.emitter.once(event, listener);
    }
    /** Remove a specific listener */
    off(event, listener) {
        this.emitter.off(event, listener);
    }
    /** Replay events from SQLite since a given event ID (for crash recovery) */
    replay(sinceId) {
        return this.store.getEventsSince(sinceId);
    }
    /** Get recent events for display */
    getRecent(limit = 50) {
        return this.store.getRecentEvents(limit);
    }
    // --- Private helpers ---
    inferSeverity(event, args) {
        if (event === 'task:failed')
            return 'warning';
        if (event === 'user:notify' && args.length > 0)
            return String(args[0]);
        if (event.startsWith('daemon:'))
            return 'info';
        return 'info';
    }
    inferAgentId(event, args) {
        if (event === 'agent:registered' && args[0])
            return args[0].id;
        if (event === 'agent:status' && typeof args[0] === 'string')
            return args[0];
        if (event === 'agent:message' && args[0])
            return args[0].from;
        if (event === 'task:assigned' && typeof args[1] === 'string')
            return args[1];
        return undefined;
    }
    inferTaskId(event, args) {
        if (event === 'task:created' && args[0])
            return args[0].id;
        if (event === 'task:assigned' && typeof args[0] === 'string')
            return args[0];
        if (event === 'task:progress' && typeof args[0] === 'string')
            return args[0];
        if (event === 'task:completed' && typeof args[0] === 'string')
            return args[0];
        if (event === 'task:failed' && typeof args[0] === 'string')
            return args[0];
        return undefined;
    }
    appendJsonl(event, severity, agentId, args) {
        try {
            const entry = {
                ts: new Date().toISOString(),
                agent: agentId || 'orchestrator',
                hook: 'orchestrator',
                type: event,
                data: { severity, args },
            };
            fs_1.default.appendFileSync(this.jsonlPath, JSON.stringify(entry) + '\n');
        }
        catch {
            // Non-critical — don't crash the bus if JSONL write fails
        }
    }
}
exports.OrchestratorEventBus = OrchestratorEventBus;
OrchestratorEventBus.instance = null;
//# sourceMappingURL=event-bus.js.map