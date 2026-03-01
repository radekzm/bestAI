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

export function useEventBus(dbPath: string): EventBusData {
  const [data, setData] = useState<EventBusData>({
    events: [],
    notifications: [],
    totalEvents: 0,
  });
  const storeRef = useRef<StateStore | null>(null);
  const lastIdRef = useRef<number>(0);
  const eventsRef = useRef<EventRow[]>([]);
  const notificationsRef = useRef<Notification[]>([]);

  useEffect(() => {
    try {
      storeRef.current = new StateStore(dbPath);
    } catch {
      return;
    }

    // Initial load
    const store = storeRef.current;
    const recent = store.getRecentEvents(MAX_EVENTS);
    if (recent.length > 0) {
      eventsRef.current = recent.reverse(); // chronological
      lastIdRef.current = recent[recent.length - 1]?.id ?? 0;

      // Extract notifications from initial events
      for (const e of eventsRef.current) {
        if (isNotification(e)) {
          notificationsRef.current.push(eventToNotification(e));
        }
      }
      if (notificationsRef.current.length > MAX_NOTIFICATIONS) {
        notificationsRef.current = notificationsRef.current.slice(-MAX_NOTIFICATIONS);
      }
    }

    function poll() {
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
    }

    // Set initial state
    setData({
      events: [...eventsRef.current],
      notifications: [...notificationsRef.current],
      totalEvents: lastIdRef.current,
    });

    const interval = setInterval(poll, POLL_MS);
    return () => {
      clearInterval(interval);
      try { storeRef.current?.close(); } catch { /* ignore */ }
      storeRef.current = null;
    };
  }, [dbPath]);

  return data;
}

function isNotification(e: EventRow): boolean {
  // Notifications: user:notify, severity >= warning, agent:message
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
