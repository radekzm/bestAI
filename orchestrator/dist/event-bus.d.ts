import { StateStore } from './state-store';
import { OrchestratorEvents, EventRow } from './types';
type EventKey = keyof OrchestratorEvents;
type EventCallback<K extends EventKey> = OrchestratorEvents[K];
/**
 * Typed event bus with:
 * - Type-safe emit/on via OrchestratorEvents
 * - Every event persisted to SQLite events table
 * - JSONL bridge for backward compat with hooks/lib-event-bus.sh
 * - Replay from SQLite for crash recovery
 */
export declare class OrchestratorEventBus {
    private emitter;
    private store;
    private jsonlPath;
    private static instance;
    private constructor();
    static create(store: StateStore, bestaiDir?: string): OrchestratorEventBus;
    static getInstance(): OrchestratorEventBus | null;
    static reset(): void;
    /** Type-safe event emission — persists to SQLite + JSONL, then emits in-memory */
    emit<K extends EventKey>(event: K, ...args: Parameters<EventCallback<K>>): void;
    /** Type-safe event subscription */
    on<K extends EventKey>(event: K, listener: EventCallback<K>): void;
    /** One-time listener */
    once<K extends EventKey>(event: K, listener: EventCallback<K>): void;
    /** Remove a specific listener */
    off<K extends EventKey>(event: K, listener: EventCallback<K>): void;
    /** Replay events from SQLite since a given event ID (for crash recovery) */
    replay(sinceId: number): EventRow[];
    /** Get recent events for display */
    getRecent(limit?: number): EventRow[];
    private inferSeverity;
    private inferAgentId;
    private inferTaskId;
    private appendJsonl;
}
export {};
