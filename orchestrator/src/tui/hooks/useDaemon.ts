// tui/hooks/useDaemon.ts — Read daemon status from DB

import { useState, useEffect } from 'react';
import { Daemon } from '../../daemon';

export interface DaemonData {
  running: boolean;
  pid: number | null;
  startedAt: string | null;
  version: string | null;
  pendingTasks: number;
  lastCheckpoint: string | null;
}

const POLL_MS = 3000;

function readDaemonStatus(): DaemonData {
  try {
    const daemon = new Daemon();
    const status = daemon.status();
    return {
      running: status.running,
      pid: status.pid,
      startedAt: status.startedAt,
      version: status.version,
      pendingTasks: status.pendingTasks,
      lastCheckpoint: status.lastCheckpoint,
    };
  } catch {
    return { running: false, pid: null, startedAt: null, version: null, pendingTasks: 0, lastCheckpoint: null };
  }
}

export function useDaemon(): DaemonData {
  // Synchronous initial read — data ready before first paint
  const [data, setData] = useState<DaemonData>(readDaemonStatus);

  useEffect(() => {
    const interval = setInterval(() => {
      setData(readDaemonStatus());
    }, POLL_MS);
    return () => { clearInterval(interval); };
  }, []);

  return data;
}
