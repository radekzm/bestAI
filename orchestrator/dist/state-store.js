"use strict";
// orchestrator/src/state-store.ts — SQLite state persistence
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StateStore = void 0;
const better_sqlite3_1 = __importDefault(require("better-sqlite3"));
const path_1 = __importDefault(require("path"));
const fs_1 = __importDefault(require("fs"));
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
class StateStore {
    constructor(dbPath) {
        const resolvedPath = dbPath || path_1.default.join(process.cwd(), '.bestai', 'orchestrator.db');
        fs_1.default.mkdirSync(path_1.default.dirname(resolvedPath), { recursive: true });
        this.db = new better_sqlite3_1.default(resolvedPath);
        this.db.pragma('journal_mode = WAL');
        this.db.pragma('foreign_keys = ON');
        this.db.exec(SCHEMA_SQL);
    }
    // --- Agent operations ---
    registerAgent(config) {
        const now = Date.now();
        this.db.prepare(`
      INSERT OR REPLACE INTO agents (id, name, level, role, parent_id, model, status, config, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(config.id, config.name, config.level, config.role, config.parentId || null, config.model || null, config.status || 'idle', JSON.stringify(config), now, now);
    }
    getAgent(id) {
        const row = this.db.prepare('SELECT * FROM agents WHERE id = ?').get(id);
        if (!row)
            return null;
        return this.rowToAgentConfig(row);
    }
    getAllAgents() {
        const rows = this.db.prepare('SELECT * FROM agents ORDER BY level, name').all();
        return rows.map((r) => this.rowToAgentConfig(r));
    }
    updateAgentStatus(id, status) {
        this.db.prepare('UPDATE agents SET status = ?, updated_at = ? WHERE id = ?')
            .run(status, Date.now(), id);
    }
    getAgentsByRole(role) {
        const rows = this.db.prepare('SELECT * FROM agents WHERE role = ? AND status = ?')
            .all(role, 'idle');
        return rows.map((r) => this.rowToAgentConfig(r));
    }
    getAgentsByLevel(level) {
        const rows = this.db.prepare('SELECT * FROM agents WHERE level = ?')
            .all(level);
        return rows.map((r) => this.rowToAgentConfig(r));
    }
    getChildAgents(parentId) {
        const rows = this.db.prepare('SELECT * FROM agents WHERE parent_id = ?')
            .all(parentId);
        return rows.map((r) => this.rowToAgentConfig(r));
    }
    removeAgent(id) {
        this.db.prepare('DELETE FROM agents WHERE id = ?').run(id);
    }
    rowToAgentConfig(row) {
        return {
            id: row.id,
            name: row.name,
            level: row.level,
            role: row.role,
            parentId: row.parent_id || undefined,
            model: row.model || undefined,
            status: row.status,
            maxConcurrentTasks: JSON.parse(row.config)?.maxConcurrentTasks ?? 1,
        };
    }
    // --- Task operations ---
    createTask(task) {
        this.db.prepare(`
      INSERT INTO tasks (id, description, status, assigned_agent, parent_task_id, dependencies, result, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(task.id, task.description, task.status, task.assignedAgent || null, task.parentTaskId || null, JSON.stringify(task.dependencies), task.result ? JSON.stringify(task.result) : null, task.createdAt, task.updatedAt);
    }
    getTask(id) {
        const row = this.db.prepare('SELECT * FROM tasks WHERE id = ?').get(id);
        if (!row)
            return null;
        return this.rowToTask(row);
    }
    getAllTasks() {
        const rows = this.db.prepare('SELECT * FROM tasks ORDER BY created_at DESC').all();
        return rows.map((r) => this.rowToTask(r));
    }
    getPendingTasks() {
        const rows = this.db.prepare("SELECT * FROM tasks WHERE status IN ('pending', 'assigned') ORDER BY created_at").all();
        return rows.map((r) => this.rowToTask(r));
    }
    getIncompleteTasks() {
        const rows = this.db.prepare("SELECT * FROM tasks WHERE status IN ('pending', 'assigned', 'running') ORDER BY created_at").all();
        return rows.map((r) => this.rowToTask(r));
    }
    updateTaskStatus(id, status, result) {
        if (result !== undefined) {
            this.db.prepare('UPDATE tasks SET status = ?, result = ?, updated_at = ? WHERE id = ?')
                .run(status, JSON.stringify(result), Date.now(), id);
        }
        else {
            this.db.prepare('UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?')
                .run(status, Date.now(), id);
        }
    }
    assignTask(taskId, agentId) {
        this.db.prepare('UPDATE tasks SET assigned_agent = ?, status = ?, updated_at = ? WHERE id = ?')
            .run(agentId, 'assigned', Date.now(), taskId);
    }
    rowToTask(row) {
        return {
            id: row.id,
            description: row.description,
            status: row.status,
            assignedAgent: row.assigned_agent || undefined,
            parentTaskId: row.parent_task_id || undefined,
            dependencies: JSON.parse(row.dependencies),
            result: row.result ? JSON.parse(row.result) : undefined,
            createdAt: row.created_at,
            updatedAt: row.updated_at,
        };
    }
    // --- Event operations ---
    insertEvent(type, severity, agentId, taskId, payload) {
        const result = this.db.prepare(`
      INSERT INTO events (type, severity, agent_id, task_id, payload, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).run(type, severity, agentId || null, taskId || null, JSON.stringify(payload ?? {}), Date.now());
        return result.lastInsertRowid;
    }
    getEventsSince(sinceId) {
        return this.db.prepare('SELECT * FROM events WHERE id > ? ORDER BY id')
            .all(sinceId);
    }
    getRecentEvents(limit = 50) {
        return this.db.prepare('SELECT * FROM events ORDER BY id DESC LIMIT ?')
            .all(limit);
    }
    // --- Daemon state operations ---
    setDaemonState(key, value) {
        this.db.prepare(`
      INSERT OR REPLACE INTO daemon_state (key, value, updated_at)
      VALUES (?, ?, ?)
    `).run(key, value, Date.now());
    }
    getDaemonState(key) {
        const row = this.db.prepare('SELECT value FROM daemon_state WHERE key = ?')
            .get(key);
        return row?.value ?? null;
    }
    clearDaemonState() {
        this.db.prepare('DELETE FROM daemon_state').run();
    }
    // --- Lifecycle ---
    close() {
        this.db.close();
    }
}
exports.StateStore = StateStore;
//# sourceMappingURL=state-store.js.map