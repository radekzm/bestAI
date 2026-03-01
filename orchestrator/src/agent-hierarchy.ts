// orchestrator/src/agent-hierarchy.ts — N-level agent hierarchy and message routing

import { AgentConfig, AgentMessage, Severity } from './types';
import { StateStore } from './state-store';
import { OrchestratorEventBus } from './event-bus';
import { AgentManager } from './agent-manager';
import crypto from 'crypto';

/** Severity ordering for threshold filtering */
const SEVERITY_ORDER: Record<Severity, number> = {
  info: 0,
  warning: 1,
  critical: 2,
  blocker: 3,
};

/** Default: only escalate warning+ to parent */
const DEFAULT_ESCALATION_THRESHOLD: Severity = 'warning';

export class AgentHierarchy {
  private store: StateStore;
  private bus: OrchestratorEventBus;
  private agentManager: AgentManager;
  private escalationThresholds: Map<string, Severity> = new Map();

  constructor(store: StateStore, bus: OrchestratorEventBus, agentManager: AgentManager) {
    this.store = store;
    this.bus = bus;
    this.agentManager = agentManager;
  }

  /** Set the minimum severity for an agent to escalate to its parent */
  setEscalationThreshold(agentId: string, threshold: Severity): void {
    this.escalationThresholds.set(agentId, threshold);
  }

  /** Route a message to its destination */
  send(message: AgentMessage): void {
    this.bus.emit('agent:message', message);

    if (message.to === '*') {
      // Broadcast to all agents
      const agents = this.store.getAllAgents();
      for (const agent of agents) {
        if (agent.id !== message.from) {
          this.deliverToAgent(agent.id, message);
        }
      }
    } else {
      this.deliverToAgent(message.to, message);
    }
  }

  /** Escalate a message to the sender's parent agent */
  escalate(message: AgentMessage): void {
    const sender = this.store.getAgent(message.from);
    if (!sender?.parentId) {
      // Root agent — escalate to user
      this.bus.emit('user:notify', message.severity, JSON.stringify(message.payload));
      return;
    }

    const threshold = this.escalationThresholds.get(sender.parentId) || DEFAULT_ESCALATION_THRESHOLD;
    if (SEVERITY_ORDER[message.severity] < SEVERITY_ORDER[threshold]) {
      return; // Below parent's threshold, filter out
    }

    const escalated: AgentMessage = {
      ...message,
      id: crypto.randomUUID(),
      to: sender.parentId,
      type: 'escalation',
      timestamp: Date.now(),
    };

    this.send(escalated);
  }

  /** Broadcast to all agents at a specific hierarchy level */
  broadcastToLevel(message: AgentMessage, level: number): void {
    const agents = this.store.getAgentsByLevel(level);
    for (const agent of agents) {
      if (agent.id !== message.from) {
        const msg: AgentMessage = {
          ...message,
          id: crypto.randomUUID(),
          to: agent.id,
          timestamp: Date.now(),
        };
        this.deliverToAgent(agent.id, msg);
      }
    }
    this.bus.emit('agent:message', message);
  }

  /** Broadcast to all descendants of a given agent */
  broadcastToSubtree(message: AgentMessage, rootAgentId: string): void {
    const descendants = this.getDescendants(rootAgentId);
    for (const agent of descendants) {
      if (agent.id !== message.from) {
        const msg: AgentMessage = {
          ...message,
          id: crypto.randomUUID(),
          to: agent.id,
          timestamp: Date.now(),
        };
        this.deliverToAgent(agent.id, msg);
      }
    }
  }

  /** Delegate a task down to the best available child of an agent */
  delegate(fromAgentId: string, message: AgentMessage): string | null {
    const children = this.store.getChildAgents(fromAgentId);
    const available = children.filter((c) => c.status === 'idle');

    if (available.length === 0) return null;

    // Pick the first available child (future: smarter selection)
    const target = available[0];
    const delegated: AgentMessage = {
      ...message,
      id: crypto.randomUUID(),
      from: fromAgentId,
      to: target.id,
      type: 'task_request',
      timestamp: Date.now(),
    };

    this.send(delegated);
    return target.id;
  }

  /** Get ancestor chain from agent to root */
  getAncestors(agentId: string): AgentConfig[] {
    const ancestors: AgentConfig[] = [];
    let current = this.store.getAgent(agentId);

    while (current?.parentId) {
      const parent = this.store.getAgent(current.parentId);
      if (!parent) break;
      ancestors.push(parent);
      current = parent;
    }

    return ancestors;
  }

  /** Get all descendants of an agent (BFS) */
  getDescendants(agentId: string): AgentConfig[] {
    const descendants: AgentConfig[] = [];
    const queue = [agentId];

    while (queue.length > 0) {
      const currentId = queue.shift()!;
      const children = this.store.getChildAgents(currentId);
      for (const child of children) {
        descendants.push(child);
        queue.push(child.id);
      }
    }

    return descendants;
  }

  /** Get the root agent (level 0) */
  getRoot(): AgentConfig | null {
    const roots = this.store.getAgentsByLevel(0);
    return roots.length > 0 ? roots[0] : null;
  }

  /** Get the depth of the hierarchy tree */
  getMaxDepth(): number {
    const agents = this.store.getAllAgents();
    return agents.reduce((max, a) => Math.max(max, a.level), 0);
  }

  /** Notify user — messages from level 0 always reach the user, deeper levels filtered by severity */
  notifyUser(agentId: string, severity: Severity, message: string): void {
    const agent = this.store.getAgent(agentId);
    if (!agent) return;

    if (agent.level === 0) {
      // Root agent always notifies user
      this.bus.emit('user:notify', severity, message);
    } else if (SEVERITY_ORDER[severity] >= SEVERITY_ORDER['critical']) {
      // Deep agents only notify on critical+
      this.bus.emit('user:notify', severity, `[${agent.name}] ${message}`);
    } else {
      // Otherwise escalate through the chain
      this.escalate({
        id: crypto.randomUUID(),
        from: agentId,
        to: agent.parentId || '*',
        type: 'status_update',
        severity,
        payload: { message },
        timestamp: Date.now(),
      });
    }
  }

  // --- Private ---

  private deliverToAgent(agentId: string, message: AgentMessage): void {
    // Try IPC delivery to running process
    const delivered = this.agentManager.sendToAgent(agentId, message as unknown as Record<string, unknown>);
    if (!delivered) {
      // Agent not running — queue the message as a task event
      this.bus.emit('user:notify', 'info', `Message queued for offline agent ${agentId}`);
    }
  }
}
