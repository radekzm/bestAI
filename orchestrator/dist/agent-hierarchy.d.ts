import { AgentConfig, AgentMessage, Severity } from './types';
import { StateStore } from './state-store';
import { OrchestratorEventBus } from './event-bus';
import { AgentManager } from './agent-manager';
export declare class AgentHierarchy {
    private store;
    private bus;
    private agentManager;
    private escalationThresholds;
    constructor(store: StateStore, bus: OrchestratorEventBus, agentManager: AgentManager);
    /** Set the minimum severity for an agent to escalate to its parent */
    setEscalationThreshold(agentId: string, threshold: Severity): void;
    /** Route a message to its destination */
    send(message: AgentMessage): void;
    /** Escalate a message to the sender's parent agent */
    escalate(message: AgentMessage): void;
    /** Broadcast to all agents at a specific hierarchy level */
    broadcastToLevel(message: AgentMessage, level: number): void;
    /** Broadcast to all descendants of a given agent */
    broadcastToSubtree(message: AgentMessage, rootAgentId: string): void;
    /** Delegate a task down to the best available child of an agent */
    delegate(fromAgentId: string, message: AgentMessage): string | null;
    /** Get ancestor chain from agent to root */
    getAncestors(agentId: string): AgentConfig[];
    /** Get all descendants of an agent (BFS) */
    getDescendants(agentId: string): AgentConfig[];
    /** Get the root agent (level 0) */
    getRoot(): AgentConfig | null;
    /** Get the depth of the hierarchy tree */
    getMaxDepth(): number;
    /** Notify user — messages from level 0 always reach the user, deeper levels filtered by severity */
    notifyUser(agentId: string, severity: Severity, message: string): void;
    private deliverToAgent;
}
