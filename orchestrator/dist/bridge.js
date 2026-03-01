"use strict";
// orchestrator/src/bridge.ts — Bridge to bestAI v1.0 tools
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.BestAIBridge = void 0;
const child_process_1 = require("child_process");
const util_1 = require("util");
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const execFileAsync = (0, util_1.promisify)(child_process_1.execFile);
/**
 * Bridge between the TypeScript orchestrator and the existing
 * bestAI v1.0 bash toolkit. Calls existing scripts via execFile
 * (safe from shell injection) and parses their output.
 */
class BestAIBridge {
    constructor(baseDir) {
        this.baseDir = baseDir || path_1.default.join(__dirname, '..', '..');
        this.bestaiDir = path_1.default.join(process.cwd(), '.bestai');
    }
    /** Call tools/task-router.sh to route a task */
    async callTaskRouter(task) {
        return this.execTool('tools/task-router.sh', ['--task', task, '--json']);
    }
    /** Call tools/swarm-dispatch.sh to dispatch a swarm task */
    async callSwarmDispatch(task, vendor, depth) {
        const args = ['--task', task];
        if (vendor)
            args.push('--vendor', vendor);
        if (depth)
            args.push('--depth', depth);
        return this.execTool('tools/swarm-dispatch.sh', args);
    }
    /** Read GPS (Global Project State) */
    readGPS() {
        const gpsPath = path_1.default.join(this.bestaiDir, 'GPS.json');
        try {
            const content = fs_1.default.readFileSync(gpsPath, 'utf-8');
            return JSON.parse(content);
        }
        catch {
            return null;
        }
    }
    /** Write to GPS with atomic write */
    writeGPS(data) {
        const gpsPath = path_1.default.join(this.bestaiDir, 'GPS.json');
        const tmpPath = gpsPath + '.tmp';
        fs_1.default.mkdirSync(path_1.default.dirname(gpsPath), { recursive: true });
        fs_1.default.writeFileSync(tmpPath, JSON.stringify(data, null, 2));
        fs_1.default.renameSync(tmpPath, gpsPath);
    }
    /** Read events from the shared event log */
    readEvents(since) {
        const cacheDir = path_1.default.join(process.env.HOME || '/root', '.cache', 'bestai');
        const eventsPath = path_1.default.join(cacheDir, 'events.jsonl');
        try {
            const content = fs_1.default.readFileSync(eventsPath, 'utf-8');
            const lines = content.trim().split('\n').filter(Boolean);
            const events = lines.map((line) => {
                try {
                    return JSON.parse(line);
                }
                catch {
                    return null;
                }
            }).filter(Boolean);
            if (since) {
                const sinceDate = new Date(since);
                return events.filter((e) => {
                    const ts = e.ts ? new Date(e.ts) : new Date(0);
                    return ts > sinceDate;
                });
            }
            return events;
        }
        catch {
            return [];
        }
    }
    /** Call tools/budget-monitor.sh */
    async callBudgetMonitor() {
        return this.execTool('tools/budget-monitor.sh', []);
    }
    /** Call tools/cockpit.sh in JSON mode */
    async callCockpit() {
        return this.execTool('tools/cockpit.sh', ['--json']);
    }
    /** Call tools/agent-sandbox.sh to run something in a sandbox */
    async callSandbox(command) {
        return this.execTool('tools/agent-sandbox.sh', [command]);
    }
    // --- Private ---
    async execTool(relativePath, args) {
        const toolPath = path_1.default.join(this.baseDir, relativePath);
        if (!fs_1.default.existsSync(toolPath)) {
            return {
                success: false,
                stdout: '',
                stderr: `Tool not found: ${relativePath}`,
            };
        }
        try {
            const { stdout, stderr } = await execFileAsync('bash', [toolPath, ...args], {
                cwd: process.cwd(),
                timeout: 30000,
                env: {
                    ...process.env,
                    BESTAI_ORCHESTRATOR: '1',
                },
            });
            return { success: true, stdout, stderr };
        }
        catch (err) {
            const error = err;
            return {
                success: false,
                stdout: error.stdout || '',
                stderr: error.stderr || error.message || 'Unknown error',
            };
        }
    }
}
exports.BestAIBridge = BestAIBridge;
//# sourceMappingURL=bridge.js.map