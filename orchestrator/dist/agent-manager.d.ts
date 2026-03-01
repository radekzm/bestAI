import { AgentConfig, AgentRole } from './types';
import { StateStore } from './state-store';
import { OrchestratorEventBus } from './event-bus';
export declare class AgentManager {
    private running;
    private store;
    private bus;
    private heartbeatInterval;
    constructor(store: StateStore, bus: OrchestratorEventBus);
    /** Register an agent in the store and emit event */
    register(config: AgentConfig): void;
    /** Spawn an agent as a child process */
    spawn(agentId: string, scriptPath?: string): boolean;
    /** Graceful kill: send shutdown message, then SIGTERM after timeout */
    kill(agentId: string): Promise<void>;
    /** Update heartbeat timestamp */
    heartbeat(agentId: string): void;
    /** Find idle agents matching a role */
    getAvailable(role?: AgentRole): AgentConfig[];
    /** Get all registered agents */
    getAll(): AgentConfig[];
    /** Check if an agent is currently running */
    isRunning(agentId: string): boolean;
    /** Start the heartbeat monitor */
    startMonitor(): void;
    /** Stop the heartbeat monitor */
    stopMonitor(): void;
    /** Gracefully shutdown all running agents */
    shutdownAll(): Promise<void>;
    /** Send a message to an agent via IPC */
    sendToAgent(agentId: string, message: Record<string, unknown>): boolean;
    private handleAgentExit;
    private handleAgentMessage;
    private checkHeartbeats;
}
