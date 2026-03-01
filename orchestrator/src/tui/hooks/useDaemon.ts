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

export function useDaemon(): DaemonData {
  const [data, setData] = useState<DaemonData>({
    running: false,
    pid: null,
    startedAt: null,
    version: null,
    pendingTasks: 0,
    lastCheckpoint: null,
  });

  useEffect(() => {
    function poll() {
      try {
        const daemon = new Daemon();
        const status = daemon.status();
        setData({
          running: status.running,
          pid: status.pid,
          startedAt: status.startedAt,
          version: status.version,
          pendingTasks: status.pendingTasks,
          lastCheckpoint: status.lastCheckpoint,
        });
      } catch {
        setData((prev) => ({ ...prev, running: false }));
      }
    }

    poll();
    const interval = setInterval(poll, POLL_MS);
    return () => { clearInterval(interval); };
  }, []);

  return data;
}
