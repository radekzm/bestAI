import { StateStore } from './state-store';
import { OrchestratorEventBus } from './event-bus';
import { AgentManager } from './agent-manager';
import { AgentHierarchy } from './agent-hierarchy';
import { BestAIBridge } from './bridge';
import { AgentMessage, OrchestratorTask } from './types';
export declare class Orchestrator {
    private store;
    private bus;
    private agentManager;
    private hierarchy;
    private bridge;
    private processingTimer;
    constructor(store: StateStore, bus: OrchestratorEventBus, agentManager: AgentManager, hierarchy: AgentHierarchy);
    /** Submit a new task to the orchestrator */
    submitTask(description: string, parentTaskId?: string, dependencies?: string[]): OrchestratorTask;
    /** Process an incoming agent message through the hierarchy */
    processMessage(message: AgentMessage): void;
    /** Push notification to user if severity meets threshold */
    notifyUser(severity: string, message: string): void;
    /** Start the task processing loop */
    startProcessingLoop(): void;
    /** Stop the task processing loop */
    stopProcessingLoop(): void;
    /** Use the bestAI task router to determine the best approach */
    routeTask(description: string): Promise<{
        vendor?: string;
        depth?: string;
    }>;
    /** Get the bridge for direct access to bestAI tools */
    getBridge(): BestAIBridge;
    private processTasks;
    private areDependenciesMet;
    private inferRole;
    private handleTaskResult;
    private handleStatusUpdate;
    private handleTaskRequest;
}
