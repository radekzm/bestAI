// tui/hooks/useStore.ts — Poll SQLite for agents and tasks

import { useState, useEffect, useRef } from 'react';
import { StateStore } from '../../state-store';
import { AgentConfig, OrchestratorTask } from '../../types';

interface StoreData {
  agents: AgentConfig[];
  tasks: OrchestratorTask[];
  agentsByLevel: Map<number, AgentConfig[]>;
  maxDepth: number;
  totalAgents: number;
  totalTasks: number;
}

const POLL_MS = 2000;

function readStore(store: StateStore): StoreData {
  const agents = store.getAllAgents();
  const tasks = store.getAllTasks();

  const byLevel = new Map<number, AgentConfig[]>();
  let maxDepth = 0;
  for (const a of agents) {
    if (!byLevel.has(a.level)) byLevel.set(a.level, []);
    byLevel.get(a.level)!.push(a);
    if (a.level > maxDepth) maxDepth = a.level;
  }

  return {
    agents,
    tasks,
    agentsByLevel: byLevel,
    maxDepth,
    totalAgents: agents.length,
    totalTasks: tasks.length,
  };
}

function readInitial(dbPath: string): { data: StoreData; store: StateStore | null } {
  try {
    const store = new StateStore(dbPath);
    return { data: readStore(store), store };
  } catch {
    return {
      data: { agents: [], tasks: [], agentsByLevel: new Map(), maxDepth: 0, totalAgents: 0, totalTasks: 0 },
      store: null,
    };
  }
}

export function useStore(dbPath: string): StoreData {
  // Synchronous initial read — data ready before first paint
  const initialRef = useRef(readInitial(dbPath));
  const storeRef = useRef<StateStore | null>(initialRef.current.store);
  const [data, setData] = useState<StoreData>(initialRef.current.data);

  useEffect(() => {
    // Store already opened in initialRef
    const interval = setInterval(() => {
      const store = storeRef.current;
      if (!store) return;
      try {
        setData(readStore(store));
      } catch {
        // DB might be locked briefly
      }
    }, POLL_MS);

    return () => {
      clearInterval(interval);
      try { storeRef.current?.close(); } catch { /* ignore */ }
      storeRef.current = null;
    };
  }, [dbPath]);

  return data;
}
