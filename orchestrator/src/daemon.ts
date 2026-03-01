// orchestrator/src/daemon.ts — Daemon lifecycle management

import fs from 'fs';
import path from 'path';
import { StateStore } from './state-store';
import { OrchestratorEventBus } from './event-bus';
import { AgentManager } from './agent-manager';
import { AgentHierarchy } from './agent-hierarchy';
import { Orchestrator } from './orchestrator';
import { AgentConfig } from './types';

const CHECKPOINT_INTERVAL_MS = 30_000;
const VERSION = '1.0.0';

export interface DaemonPaths {
  bestaiDir: string;
  pidFile: string;
  dbFile: string;
}

export class Daemon {
  private paths: DaemonPaths;
  private store: StateStore | null = null;
  private bus: OrchestratorEventBus | null = null;
  private agentManager: AgentManager | null = null;
  private hierarchy: AgentHierarchy | null = null;
  private orchestrator: Orchestrator | null = null;
  private checkpointTimer: ReturnType<typeof setInterval> | null = null;

  constructor(workDir?: string) {
    const base = workDir || process.cwd();
    const bestaiDir = path.join(base, '.bestai');
    this.paths = {
      bestaiDir,
      pidFile: path.join(bestaiDir, 'daemon.pid'),
      dbFile: path.join(bestaiDir, 'orchestrator.db'),
    };
  }

  /** Start the daemon */
  async start(): Promise<void> {
    // Check for existing daemon
    if (this.isRunning()) {
      const pid = this.readPid();
      console.error(`Daemon already running (PID ${pid})`);
      process.exit(1);
    }

    fs.mkdirSync(this.paths.bestaiDir, { recursive: true });

    // Initialize components
    this.store = new StateStore(this.paths.dbFile);
    this.bus = OrchestratorEventBus.create(this.store, this.paths.bestaiDir);
    this.agentManager = new AgentManager(this.store, this.bus);
    this.hierarchy = new AgentHierarchy(this.store, this.bus, this.agentManager);
    this.orchestrator = new Orchestrator(this.store, this.bus, this.agentManager, this.hierarchy);

    // Write PID
    fs.writeFileSync(this.paths.pidFile, String(process.pid));

    // Store daemon state
    this.store.setDaemonState('pid', String(process.pid));
    this.store.setDaemonState('startedAt', new Date().toISOString());
    this.store.setDaemonState('version', VERSION);

    // Register built-in agents
    this.registerBuiltinAgents();

    // Recovery: handle tasks that were in-flight when daemon died
    this.recoverIncompleteTasks();

    // Start heartbeat monitor
    this.agentManager.startMonitor();

    // Start task processing loop
    this.orchestrator.startProcessingLoop();

    // Start checkpoint timer
    this.checkpointTimer = setInterval(() => {
      this.checkpoint();
    }, CHECKPOINT_INTERVAL_MS);

    // Handle signals
    process.on('SIGTERM', () => this.stop());
    process.on('SIGINT', () => this.stop());

    this.bus.emit('daemon:started');
    console.log(`Daemon started (PID ${process.pid})`);
  }

  /** Stop the daemon gracefully */
  async stop(): Promise<void> {
    console.log('Shutting down daemon...');

    if (this.checkpointTimer) {
      clearInterval(this.checkpointTimer);
      this.checkpointTimer = null;
    }

    if (this.orchestrator) {
      this.orchestrator.stopProcessingLoop();
    }

    if (this.agentManager) {
      await this.agentManager.shutdownAll();
    }

    this.checkpoint();

    if (this.bus) {
      this.bus.emit('daemon:stopped');
    }

    // Remove PID file
    try {
      fs.unlinkSync(this.paths.pidFile);
    } catch {
      // May already be gone
    }

    if (this.store) {
      this.store.clearDaemonState();
      this.store.close();
    }

    OrchestratorEventBus.reset();
    console.log('Daemon stopped');
  }

  /** Get daemon status */
  status(): {
    running: boolean;
    pid: number | null;
    startedAt: string | null;
    version: string | null;
    agents: AgentConfig[];
    pendingTasks: number;
    lastCheckpoint: string | null;
  } {
    const running = this.isRunning();
    const pid = this.readPid();

    if (!running) {
      return {
        running: false,
        pid: null,
        startedAt: null,
        version: null,
        agents: [],
        pendingTasks: 0,
        lastCheckpoint: null,
      };
    }

    // Read from DB
    const store = new StateStore(this.paths.dbFile);
    const agents = store.getAllAgents();
    const pending = store.getPendingTasks();
    const startedAt = store.getDaemonState('startedAt');
    const version = store.getDaemonState('version');
    const lastCheckpoint = store.getDaemonState('lastCheckpoint');
    store.close();

    return {
      running: true,
      pid,
      startedAt,
      version,
      agents,
      pendingTasks: pending.length,
      lastCheckpoint,
    };
  }

  /** Check if daemon is currently running */
  isRunning(): boolean {
    const pid = this.readPid();
    if (!pid) return false;

    try {
      // Signal 0 checks if process exists without sending a signal
      process.kill(pid, 0);
      return true;
    } catch {
      // Process not found — stale PID file
      try { fs.unlinkSync(this.paths.pidFile); } catch { /* ignore */ }
      return false;
    }
  }

  // --- Private ---

  private readPid(): number | null {
    try {
      const content = fs.readFileSync(this.paths.pidFile, 'utf-8').trim();
      const pid = parseInt(content, 10);
      return isNaN(pid) ? null : pid;
    } catch {
      return null;
    }
  }

  private checkpoint(): void {
    if (!this.store) return;
    this.store.setDaemonState('lastCheckpoint', new Date().toISOString());
  }

  private registerBuiltinAgents(): void {
    if (!this.agentManager) return;

    const builtins: AgentConfig[] = [
      {
        id: 'main-assistant',
        name: 'Main Assistant',
        level: 0,
        role: 'assistant',
        maxConcurrentTasks: 3,
      },
      {
        id: 'guardian',
        name: 'Guardian',
        level: 1,
        role: 'guardian',
        parentId: 'main-assistant',
        maxConcurrentTasks: 2,
      },
      {
        id: 'planner',
        name: 'Planner',
        level: 1,
        role: 'planner',
        parentId: 'main-assistant',
        maxConcurrentTasks: 2,
      },
      {
        id: 'knowledge',
        name: 'Knowledge',
        level: 1,
        role: 'knowledge',
        parentId: 'main-assistant',
        maxConcurrentTasks: 2,
      },
      {
        id: 'executor-1',
        name: 'Executor 1',
        level: 2,
        role: 'executor',
        parentId: 'planner',
        maxConcurrentTasks: 1,
      },
    ];

    for (const agent of builtins) {
      this.agentManager.register(agent);
    }
  }

  private recoverIncompleteTasks(): void {
    if (!this.store || !this.bus) return;

    const incomplete = this.store.getIncompleteTasks();
    for (const task of incomplete) {
      if (task.status === 'running') {
        // Running tasks from a dead daemon → mark failed
        this.store.updateTaskStatus(task.id, 'failed', { error: 'Daemon restart recovery' });
        this.bus.emit('task:failed', task.id, 'Daemon restart recovery — task was running when daemon died');
      }
      // pending/assigned tasks stay as-is for the queue to pick up
    }

    if (incomplete.length > 0) {
      const failed = incomplete.filter((t) => t.status === 'running').length;
      const kept = incomplete.length - failed;
      this.bus.emit('user:notify', 'info',
        `Recovery: ${failed} running tasks marked failed, ${kept} pending tasks re-queued`);
    }
  }
}
