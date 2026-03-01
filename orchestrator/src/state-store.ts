// orchestrator/src/state-store.ts — SQLite state persistence

import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';
import {
  AgentConfig,
  AgentRow,
  AgentStatus,
  EventRow,
  OrchestratorTask,
  TaskRow,
  TaskStatus,
} from './types';

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS agents (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 0,
  role TEXT NOT NULL,
  parent_id TEXT,
  model TEXT,
  status TEXT DEFAULT 'idle',
  config JSON,
  created_at INTEGER,
  updated_at INTEGER
);

CREATE TABLE IF NOT EXISTS tasks (
  id TEXT PRIMARY KEY,
  description TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  assigned_agent TEXT,
  parent_task_id TEXT,
  dependencies JSON DEFAULT '[]',
  result JSON,
  created_at INTEGER,
  updated_at INTEGER
);

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  severity TEXT DEFAULT 'info',
  agent_id TEXT,
  task_id TEXT,
  payload JSON,
  created_at INTEGER
);

CREATE TABLE IF NOT EXISTS daemon_state (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at INTEGER
);
`;

export class StateStore {
  private db: Database.Database;

  constructor(dbPath?: string) {
    const resolvedPath = dbPath || path.join(process.cwd(), '.bestai', 'orchestrator.db');
    fs.mkdirSync(path.dirname(resolvedPath), { recursive: true });

    this.db = new Database(resolvedPath);
    this.db.pragma('journal_mode = WAL');
    this.db.pragma('foreign_keys = ON');
    this.db.exec(SCHEMA_SQL);
  }

  // --- Agent operations ---

  registerAgent(config: AgentConfig): void {
    const now = Date.now();
    this.db.prepare(`
      INSERT OR REPLACE INTO agents (id, name, level, role, parent_id, model, status, config, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      config.id,
      config.name,
      config.level,
      config.role,
      config.parentId || null,
      config.model || null,
      config.status || 'idle',
      JSON.stringify(config),
      now,
      now
    );
  }

  getAgent(id: string): AgentConfig | null {
    const row = this.db.prepare('SELECT * FROM agents WHERE id = ?').get(id) as AgentRow | undefined;
    if (!row) return null;
    return this.rowToAgentConfig(row);
  }

  getAllAgents(): AgentConfig[] {
    const rows = this.db.prepare('SELECT * FROM agents ORDER BY level, name').all() as AgentRow[];
    return rows.map((r) => this.rowToAgentConfig(r));
  }

  updateAgentStatus(id: string, status: AgentStatus): void {
    this.db.prepare('UPDATE agents SET status = ?, updated_at = ? WHERE id = ?')
      .run(status, Date.now(), id);
  }

  getAgentsByRole(role: string): AgentConfig[] {
    const rows = this.db.prepare('SELECT * FROM agents WHERE role = ? AND status = ?')
      .all(role, 'idle') as AgentRow[];
    return rows.map((r) => this.rowToAgentConfig(r));
  }

  getAgentsByLevel(level: number): AgentConfig[] {
    const rows = this.db.prepare('SELECT * FROM agents WHERE level = ?')
      .all(level) as AgentRow[];
    return rows.map((r) => this.rowToAgentConfig(r));
  }

  getChildAgents(parentId: string): AgentConfig[] {
    const rows = this.db.prepare('SELECT * FROM agents WHERE parent_id = ?')
      .all(parentId) as AgentRow[];
    return rows.map((r) => this.rowToAgentConfig(r));
  }

  removeAgent(id: string): void {
    this.db.prepare('DELETE FROM agents WHERE id = ?').run(id);
  }

  private rowToAgentConfig(row: AgentRow): AgentConfig {
    return {
      id: row.id,
      name: row.name,
      level: row.level,
      role: row.role as AgentConfig['role'],
      parentId: row.parent_id || undefined,
      model: row.model || undefined,
      status: row.status as AgentStatus,
      maxConcurrentTasks: JSON.parse(row.config)?.maxConcurrentTasks ?? 1,
    };
  }

  // --- Task operations ---

  createTask(task: OrchestratorTask): void {
    this.db.prepare(`
      INSERT INTO tasks (id, description, status, assigned_agent, parent_task_id, dependencies, result, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      task.id,
      task.description,
      task.status,
      task.assignedAgent || null,
      task.parentTaskId || null,
      JSON.stringify(task.dependencies),
      task.result ? JSON.stringify(task.result) : null,
      task.createdAt,
      task.updatedAt
    );
  }

  getTask(id: string): OrchestratorTask | null {
    const row = this.db.prepare('SELECT * FROM tasks WHERE id = ?').get(id) as TaskRow | undefined;
    if (!row) return null;
    return this.rowToTask(row);
  }

  getAllTasks(): OrchestratorTask[] {
    const rows = this.db.prepare('SELECT * FROM tasks ORDER BY created_at DESC').all() as TaskRow[];
    return rows.map((r) => this.rowToTask(r));
  }

  getPendingTasks(): OrchestratorTask[] {
    const rows = this.db.prepare(
      "SELECT * FROM tasks WHERE status IN ('pending', 'assigned') ORDER BY created_at"
    ).all() as TaskRow[];
    return rows.map((r) => this.rowToTask(r));
  }

  getIncompleteTasks(): OrchestratorTask[] {
    const rows = this.db.prepare(
      "SELECT * FROM tasks WHERE status IN ('pending', 'assigned', 'running') ORDER BY created_at"
    ).all() as TaskRow[];
    return rows.map((r) => this.rowToTask(r));
  }

  updateTaskStatus(id: string, status: TaskStatus, result?: unknown): void {
    if (result !== undefined) {
      this.db.prepare('UPDATE tasks SET status = ?, result = ?, updated_at = ? WHERE id = ?')
        .run(status, JSON.stringify(result), Date.now(), id);
    } else {
      this.db.prepare('UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?')
        .run(status, Date.now(), id);
    }
  }

  assignTask(taskId: string, agentId: string): void {
    this.db.prepare('UPDATE tasks SET assigned_agent = ?, status = ?, updated_at = ? WHERE id = ?')
      .run(agentId, 'assigned', Date.now(), taskId);
  }

  private rowToTask(row: TaskRow): OrchestratorTask {
    return {
      id: row.id,
      description: row.description,
      status: row.status as TaskStatus,
      assignedAgent: row.assigned_agent || undefined,
      parentTaskId: row.parent_task_id || undefined,
      dependencies: JSON.parse(row.dependencies),
      result: row.result ? JSON.parse(row.result) : undefined,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  // --- Event operations ---

  insertEvent(type: string, severity: string, agentId?: string, taskId?: string, payload?: unknown): number {
    const result = this.db.prepare(`
      INSERT INTO events (type, severity, agent_id, task_id, payload, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(type, severity, agentId || null, taskId || null, JSON.stringify(payload ?? {}), Date.now());
    return result.lastInsertRowid as number;
  }

  getEventsSince(sinceId: number): EventRow[] {
    return this.db.prepare('SELECT * FROM events WHERE id > ? ORDER BY id')
      .all(sinceId) as EventRow[];
  }

  getRecentEvents(limit: number = 50): EventRow[] {
    return this.db.prepare('SELECT * FROM events ORDER BY id DESC LIMIT ?')
      .all(limit) as EventRow[];
  }

  // --- Daemon state operations ---

  setDaemonState(key: string, value: string): void {
    this.db.prepare(`
      INSERT OR REPLACE INTO daemon_state (key, value, updated_at)
      VALUES (?, ?, ?)
    `).run(key, value, Date.now());
  }

  getDaemonState(key: string): string | null {
    const row = this.db.prepare('SELECT value FROM daemon_state WHERE key = ?')
      .get(key) as { value: string } | undefined;
    return row?.value ?? null;
  }

  clearDaemonState(): void {
    this.db.prepare('DELETE FROM daemon_state').run();
  }

  // --- Lifecycle ---

  close(): void {
    this.db.close();
  }
}
