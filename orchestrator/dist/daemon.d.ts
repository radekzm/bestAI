import { AgentConfig } from './types';
export interface DaemonPaths {
    bestaiDir: string;
    pidFile: string;
    dbFile: string;
}
export declare class Daemon {
    private paths;
    private store;
    private bus;
    private agentManager;
    private hierarchy;
    private orchestrator;
    private checkpointTimer;
    constructor(workDir?: string);
    /** Start the daemon */
    start(): Promise<void>;
    /** Stop the daemon gracefully */
    stop(): Promise<void>;
    /** Get daemon status */
    status(): {
        running: boolean;
        pid: number | null;
        startedAt: string | null;
        version: string | null;
        agents: AgentConfig[];
        pendingTasks: number;
        lastCheckpoint: string | null;
    };
    /** Check if daemon is currently running */
    isRunning(): boolean;
    private readPid;
    private checkpoint;
    private registerBuiltinAgents;
    private recoverIncompleteTasks;
}
