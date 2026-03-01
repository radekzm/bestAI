// orchestrator/src/bridge.ts — Bridge to bestAI v1.0 tools

import { execFile } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';

const execFileAsync = promisify(execFile);

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
export class BestAIBridge {
  private baseDir: string;
  private bestaiDir: string;

  constructor(baseDir?: string) {
    this.baseDir = baseDir || path.join(__dirname, '..', '..');
    this.bestaiDir = path.join(process.cwd(), '.bestai');
  }

  /** Call tools/task-router.sh to route a task */
  async callTaskRouter(task: string): Promise<BridgeResult> {
    return this.execTool('tools/task-router.sh', ['--task', task, '--json']);
  }

  /** Call tools/swarm-dispatch.sh to dispatch a swarm task */
  async callSwarmDispatch(task: string, vendor?: string, depth?: string): Promise<BridgeResult> {
    const args = ['--task', task];
    if (vendor) args.push('--vendor', vendor);
    if (depth) args.push('--depth', depth);
    return this.execTool('tools/swarm-dispatch.sh', args);
  }

  /** Read GPS (Global Project State) */
  readGPS(): Record<string, unknown> | null {
    const gpsPath = path.join(this.bestaiDir, 'GPS.json');
    try {
      const content = fs.readFileSync(gpsPath, 'utf-8');
      return JSON.parse(content);
    } catch {
      return null;
    }
  }

  /** Write to GPS with atomic write */
  writeGPS(data: Record<string, unknown>): void {
    const gpsPath = path.join(this.bestaiDir, 'GPS.json');
    const tmpPath = gpsPath + '.tmp';
    fs.mkdirSync(path.dirname(gpsPath), { recursive: true });
    fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2));
    fs.renameSync(tmpPath, gpsPath);
  }

  /** Read events from the shared event log */
  readEvents(since?: number): Array<Record<string, unknown>> {
    const cacheDir = path.join(
      process.env.HOME || '/root',
      '.cache', 'bestai'
    );
    const eventsPath = path.join(cacheDir, 'events.jsonl');

    try {
      const content = fs.readFileSync(eventsPath, 'utf-8');
      const lines = content.trim().split('\n').filter(Boolean);
      const events = lines.map((line) => {
        try { return JSON.parse(line); } catch { return null; }
      }).filter(Boolean);

      if (since) {
        const sinceDate = new Date(since);
        return events.filter((e: Record<string, unknown>) => {
          const ts = e.ts ? new Date(e.ts as string) : new Date(0);
          return ts > sinceDate;
        });
      }

      return events;
    } catch {
      return [];
    }
  }

  /** Call tools/budget-monitor.sh */
  async callBudgetMonitor(): Promise<BridgeResult> {
    return this.execTool('tools/budget-monitor.sh', []);
  }

  /** Call tools/cockpit.sh in JSON mode */
  async callCockpit(): Promise<BridgeResult> {
    return this.execTool('tools/cockpit.sh', ['--json']);
  }

  /** Call tools/agent-sandbox.sh to run something in a sandbox */
  async callSandbox(command: string): Promise<BridgeResult> {
    return this.execTool('tools/agent-sandbox.sh', [command]);
  }

  // --- Private ---

  private async execTool(relativePath: string, args: string[]): Promise<BridgeResult> {
    const toolPath = path.join(this.baseDir, relativePath);

    if (!fs.existsSync(toolPath)) {
      return {
        success: false,
        stdout: '',
        stderr: `Tool not found: ${relativePath}`,
      };
    }

    try {
      const { stdout, stderr } = await execFileAsync('bash', [toolPath, ...args], {
        cwd: process.cwd(),
        timeout: 30_000,
        env: {
          ...process.env,
          BESTAI_ORCHESTRATOR: '1',
        },
      });
      return { success: true, stdout, stderr };
    } catch (err: unknown) {
      const error = err as { stdout?: string; stderr?: string; message?: string };
      return {
        success: false,
        stdout: error.stdout || '',
        stderr: error.stderr || error.message || 'Unknown error',
      };
    }
  }
}
