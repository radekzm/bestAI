// orchestrator/src/types.ts — Core type definitions for bestAI orchestrator

// Agent hierarchy level — numeric depth (0 = root, 1+ = deeper)
// N-level hierarchy, not limited to a fixed set
export type AgentLevel = number;

// Agent functional roles
export type AgentRole = 'assistant' | 'guardian' | 'planner' | 'knowledge' | 'executor';

// Agent lifecycle states
export type AgentStatus = 'idle' | 'working' | 'waiting' | 'error' | 'stopped';

// Task lifecycle states
export type TaskStatus = 'pending' | 'assigned' | 'running' | 'done' | 'failed';

// Message types in the agent protocol
export type MessageType = 'task_request' | 'task_result' | 'status_update' | 'escalation' | 'question';

// Severity levels for messages and notifications
export type Severity = 'info' | 'warning' | 'critical' | 'blocker';

/** Message protocol between agents */
export interface AgentMessage {
  id: string;
  from: string;
  to: string;          // agent ID or '*' for broadcast
  type: MessageType;
  severity: Severity;
  payload: unknown;
  parentTaskId?: string;
  timestamp: number;
}

/** Task managed by the orchestrator */
export interface OrchestratorTask {
  id: string;
  description: string;
  status: TaskStatus;
  assignedAgent?: string;
  parentTaskId?: string;
  dependencies: string[];
  result?: unknown;
  createdAt: number;
  updatedAt: number;
}

/** Agent registration config */
export interface AgentConfig {
  id: string;
  name: string;
  level: AgentLevel;
  role: AgentRole;
  parentId?: string;
  model?: string;
  maxConcurrentTasks: number;
  status?: AgentStatus;
}

/** Who sent a conversation message */
export type MessageSender = 'user' | 'agent' | 'system';

/** A single message in the conversation view */
export interface ConversationMessage {
  id: number;
  timestamp: number;
  sender: MessageSender;
  agent?: string;  // agent name/id when sender === 'agent'
  text: string;
}

/** Typed event signatures for the orchestrator event bus */
export interface OrchestratorEvents {
  'daemon:started': () => void;
  'daemon:stopped': () => void;
  'agent:registered': (agent: AgentConfig) => void;
  'agent:status': (agentId: string, status: AgentStatus) => void;
  'agent:message': (message: AgentMessage) => void;
  'task:created': (task: OrchestratorTask) => void;
  'task:assigned': (taskId: string, agentId: string) => void;
  'task:progress': (taskId: string, percent: number, summary: string) => void;
  'task:completed': (taskId: string, result: unknown) => void;
  'task:failed': (taskId: string, error: string) => void;
  'user:notify': (severity: string, message: string) => void;
  'user:message': (message: string) => void;
}

/** Daemon persistent state keys */
export interface DaemonState {
  pid: string;
  startedAt: string;
  lastCheckpoint: string;
  version: string;
}

/** Row shape from the events table */
export interface EventRow {
  id: number;
  type: string;
  severity: string;
  agent_id: string | null;
  task_id: string | null;
  payload: string;
  created_at: number;
}

/** Row shape from the agents table */
export interface AgentRow {
  id: string;
  name: string;
  level: number;
  role: string;
  parent_id: string | null;
  model: string | null;
  status: string;
  config: string;
  created_at: number;
  updated_at: number;
}

/** Row shape from the tasks table */
export interface TaskRow {
  id: string;
  description: string;
  status: string;
  assigned_agent: string | null;
  parent_task_id: string | null;
  dependencies: string;
  result: string | null;
  created_at: number;
  updated_at: number;
}
