export interface DaemonData {
    running: boolean;
    pid: number | null;
    startedAt: string | null;
    version: string | null;
    pendingTasks: number;
    lastCheckpoint: string | null;
}
export declare function useDaemon(): DaemonData;
