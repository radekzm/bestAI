// orchestrator/src/event-bus.ts — Typed event bus with SQLite persistence

import { EventEmitter } from 'events';
import fs from 'fs';
import path from 'path';
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
export class OrchestratorEventBus {
  private emitter: EventEmitter;
  private store: StateStore;
  private jsonlPath: string;
  private static instance: OrchestratorEventBus | null = null;

  private constructor(store: StateStore, bestaiDir?: string) {
    this.emitter = new EventEmitter();
    this.emitter.setMaxListeners(50);
    this.store = store;

    const dir = bestaiDir || path.join(process.cwd(), '.bestai');
    fs.mkdirSync(dir, { recursive: true });
    this.jsonlPath = path.join(dir, 'event_bus.jsonl');
  }

  static create(store: StateStore, bestaiDir?: string): OrchestratorEventBus {
    if (!OrchestratorEventBus.instance) {
      OrchestratorEventBus.instance = new OrchestratorEventBus(store, bestaiDir);
    }
    return OrchestratorEventBus.instance;
  }

  static getInstance(): OrchestratorEventBus | null {
    return OrchestratorEventBus.instance;
  }

  static reset(): void {
    OrchestratorEventBus.instance = null;
  }

  /** Type-safe event emission — persists to SQLite + JSONL, then emits in-memory */
  emit<K extends EventKey>(event: K, ...args: Parameters<EventCallback<K>>): void {
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
  on<K extends EventKey>(event: K, listener: EventCallback<K>): void {
    this.emitter.on(event, listener as (...args: unknown[]) => void);
  }

  /** One-time listener */
  once<K extends EventKey>(event: K, listener: EventCallback<K>): void {
    this.emitter.once(event, listener as (...args: unknown[]) => void);
  }

  /** Remove a specific listener */
  off<K extends EventKey>(event: K, listener: EventCallback<K>): void {
    this.emitter.off(event, listener as (...args: unknown[]) => void);
  }

  /** Replay events from SQLite since a given event ID (for crash recovery) */
  replay(sinceId: number): EventRow[] {
    return this.store.getEventsSince(sinceId);
  }

  /** Get recent events for display */
  getRecent(limit: number = 50): EventRow[] {
    return this.store.getRecentEvents(limit);
  }

  // --- Private helpers ---

  private inferSeverity(event: string, args: unknown[]): string {
    if (event === 'task:failed') return 'warning';
    if (event === 'user:notify' && args.length > 0) return String(args[0]);
    if (event.startsWith('daemon:')) return 'info';
    return 'info';
  }

  private inferAgentId(event: string, args: unknown[]): string | undefined {
    if (event === 'agent:registered' && args[0]) return (args[0] as { id: string }).id;
    if (event === 'agent:status' && typeof args[0] === 'string') return args[0];
    if (event === 'agent:message' && args[0]) return (args[0] as { from: string }).from;
    if (event === 'task:assigned' && typeof args[1] === 'string') return args[1];
    return undefined;
  }

  private inferTaskId(event: string, args: unknown[]): string | undefined {
    if (event === 'task:created' && args[0]) return (args[0] as { id: string }).id;
    if (event === 'task:assigned' && typeof args[0] === 'string') return args[0];
    if (event === 'task:progress' && typeof args[0] === 'string') return args[0];
    if (event === 'task:completed' && typeof args[0] === 'string') return args[0];
    if (event === 'task:failed' && typeof args[0] === 'string') return args[0];
    return undefined;
  }

  private appendJsonl(event: string, severity: string, agentId: string | undefined, args: unknown[]): void {
    try {
      const entry = {
        ts: new Date().toISOString(),
        agent: agentId || 'orchestrator',
        hook: 'orchestrator',
        type: event,
        data: { severity, args },
      };
      fs.appendFileSync(this.jsonlPath, JSON.stringify(entry) + '\n');
    } catch {
      // Non-critical — don't crash the bus if JSONL write fails
    }
  }
}
