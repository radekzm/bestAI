import { AgentConfig, OrchestratorTask } from '../../types';
interface StoreData {
    agents: AgentConfig[];
    tasks: OrchestratorTask[];
    agentsByLevel: Map<number, AgentConfig[]>;
    maxDepth: number;
    totalAgents: number;
    totalTasks: number;
}
export declare function useStore(dbPath: string): StoreData;
export {};
