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

export function useStore(dbPath: string): StoreData {
  const [data, setData] = useState<StoreData>({
    agents: [],
    tasks: [],
    agentsByLevel: new Map(),
    maxDepth: 0,
    totalAgents: 0,
    totalTasks: 0,
  });
  const storeRef = useRef<StateStore | null>(null);

  useEffect(() => {
    try {
      storeRef.current = new StateStore(dbPath);
    } catch {
      return;
    }

    function poll() {
      const store = storeRef.current;
      if (!store) return;

      try {
        const agents = store.getAllAgents();
        const tasks = store.getAllTasks();

        const byLevel = new Map<number, AgentConfig[]>();
        let maxDepth = 0;
        for (const a of agents) {
          if (!byLevel.has(a.level)) byLevel.set(a.level, []);
          byLevel.get(a.level)!.push(a);
          if (a.level > maxDepth) maxDepth = a.level;
        }

        setData({
          agents,
          tasks,
          agentsByLevel: byLevel,
          maxDepth,
          totalAgents: agents.length,
          totalTasks: tasks.length,
        });
      } catch {
        // DB might be locked briefly
      }
    }

    poll();
    const interval = setInterval(poll, POLL_MS);

    return () => {
      clearInterval(interval);
      try { storeRef.current?.close(); } catch { /* ignore */ }
      storeRef.current = null;
    };
  }, [dbPath]);

  return data;
}
