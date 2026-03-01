/** Result from a bridge tool call */
interface BridgeResult {
    success: boolean;
    stdout: string;
    stderr: string;
}
/**
 * Bridge between the TypeScript orchestrator and the existing
 * bestAI v1.0 bash toolkit. Calls existing scripts via execFile
 * (safe from shell injection) and parses their output.
 */
export declare class BestAIBridge {
    private baseDir;
    private bestaiDir;
    constructor(baseDir?: string);
    /** Call tools/task-router.sh to route a task */
    callTaskRouter(task: string): Promise<BridgeResult>;
    /** Call tools/swarm-dispatch.sh to dispatch a swarm task */
    callSwarmDispatch(task: string, vendor?: string, depth?: string): Promise<BridgeResult>;
    /** Read GPS (Global Project State) */
    readGPS(): Record<string, unknown> | null;
    /** Write to GPS with atomic write */
    writeGPS(data: Record<string, unknown>): void;
    /** Read events from the shared event log */
    readEvents(since?: number): Array<Record<string, unknown>>;
    /** Call tools/budget-monitor.sh */
    callBudgetMonitor(): Promise<BridgeResult>;
    /** Call tools/cockpit.sh in JSON mode */
    callCockpit(): Promise<BridgeResult>;
    /** Call tools/agent-sandbox.sh to run something in a sandbox */
    callSandbox(command: string): Promise<BridgeResult>;
    private execTool;
}
export {};
