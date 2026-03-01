import { AgentConfig, AgentStatus, EventRow, OrchestratorTask, TaskStatus } from './types';
export declare class StateStore {
    private db;
    constructor(dbPath?: string);
    registerAgent(config: AgentConfig): void;
    getAgent(id: string): AgentConfig | null;
    getAllAgents(): AgentConfig[];
    updateAgentStatus(id: string, status: AgentStatus): void;
    getAgentsByRole(role: string): AgentConfig[];
    getAgentsByLevel(level: number): AgentConfig[];
    getChildAgents(parentId: string): AgentConfig[];
    removeAgent(id: string): void;
    private rowToAgentConfig;
    createTask(task: OrchestratorTask): void;
    getTask(id: string): OrchestratorTask | null;
    getAllTasks(): OrchestratorTask[];
    getPendingTasks(): OrchestratorTask[];
    getIncompleteTasks(): OrchestratorTask[];
    updateTaskStatus(id: string, status: TaskStatus, result?: unknown): void;
    assignTask(taskId: string, agentId: string): void;
    private rowToTask;
    insertEvent(type: string, severity: string, agentId?: string, taskId?: string, payload?: unknown): number;
    getEventsSince(sinceId: number): EventRow[];
    getRecentEvents(limit?: number): EventRow[];
    setDaemonState(key: string, value: string): void;
    getDaemonState(key: string): string | null;
    clearDaemonState(): void;
    close(): void;
}
