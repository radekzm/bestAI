// tui/hooks/useEventBus.ts — Poll SQLite events, filter notifications

import { useState, useEffect, useRef } from 'react';
import { StateStore } from '../../state-store';
import { EventRow } from '../../types';

export interface Notification {
  id: number;
  timestamp: number;
  severity: string;
  agent: string;
  message: string;
}

interface EventBusData {
  events: EventRow[];
  notifications: Notification[];
  totalEvents: number;
}

const POLL_MS = 1000;
const MAX_EVENTS = 200;
const MAX_NOTIFICATIONS = 50;

function isNotification(e: EventRow): boolean {
  if (e.type === 'user:notify') return true;
  if (e.severity === 'warning' || e.severity === 'critical' || e.severity === 'blocker') return true;
  return false;
}

function eventToNotification(e: EventRow): Notification {
  let message = e.type;
  try {
    const payload = JSON.parse(e.payload);
    if (typeof payload === 'string') message = payload;
    else if (payload.message) message = payload.message;
    else if (payload.description) message = payload.description;
  } catch { /* use type as message */ }

  return {
    id: e.id,
    timestamp: e.created_at,
    severity: e.severity,
    agent: e.agent_id || '-',
    message,
  };
}

interface InitialLoad {
  events: EventRow[];
  notifications: Notification[];
  lastId: number;
  store: StateStore | null;
}

function readInitial(dbPath: string): InitialLoad {
  try {
    const store = new StateStore(dbPath);
    const recent = store.getRecentEvents(MAX_EVENTS);
    if (recent.length === 0) {
      return { events: [], notifications: [], lastId: 0, store };
    }

    const events = recent.reverse(); // chronological
    const lastId = events[events.length - 1]?.id ?? 0;

    let notifications: Notification[] = [];
    for (const e of events) {
      if (isNotification(e)) {
        notifications.push(eventToNotification(e));
      }
    }
    if (notifications.length > MAX_NOTIFICATIONS) {
      notifications = notifications.slice(-MAX_NOTIFICATIONS);
    }

    return { events, notifications, lastId, store };
  } catch {
    return { events: [], notifications: [], lastId: 0, store: null };
  }
}

export function useEventBus(dbPath: string): EventBusData {
  // Synchronous initial read — data ready before first paint
  const initialRef = useRef(readInitial(dbPath));
  const storeRef = useRef<StateStore | null>(initialRef.current.store);
  const lastIdRef = useRef<number>(initialRef.current.lastId);
  const eventsRef = useRef<EventRow[]>(initialRef.current.events);
  const notificationsRef = useRef<Notification[]>(initialRef.current.notifications);

  const [data, setData] = useState<EventBusData>({
    events: initialRef.current.events,
    notifications: initialRef.current.notifications,
    totalEvents: initialRef.current.lastId,
  });

  useEffect(() => {
    const interval = setInterval(() => {
      if (!storeRef.current) return;
      try {
        const newEvents = storeRef.current.getEventsSince(lastIdRef.current);
        if (newEvents.length === 0) return;

        eventsRef.current = [...eventsRef.current, ...newEvents].slice(-MAX_EVENTS);
        lastIdRef.current = newEvents[newEvents.length - 1].id;

        for (const e of newEvents) {
          if (isNotification(e)) {
            notificationsRef.current.push(eventToNotification(e));
          }
        }
        if (notificationsRef.current.length > MAX_NOTIFICATIONS) {
          notificationsRef.current = notificationsRef.current.slice(-MAX_NOTIFICATIONS);
        }

        setData({
          events: [...eventsRef.current],
          notifications: [...notificationsRef.current],
          totalEvents: lastIdRef.current,
        });
      } catch {
        // DB briefly locked
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
