"use strict";
// tui/hooks/useEventBus.ts — Poll SQLite events, filter notifications
Object.defineProperty(exports, "__esModule", { value: true });
exports.useEventBus = useEventBus;
const react_1 = require("react");
const state_store_1 = require("../../state-store");
const POLL_MS = 1000;
const MAX_EVENTS = 200;
const MAX_NOTIFICATIONS = 50;
function isNotification(e) {
    if (e.type === 'user:notify')
        return true;
    if (e.severity === 'warning' || e.severity === 'critical' || e.severity === 'blocker')
        return true;
    return false;
}
function eventToNotification(e) {
    let message = e.type;
    try {
        const payload = JSON.parse(e.payload);
        if (typeof payload === 'string')
            message = payload;
        else if (payload.message)
            message = payload.message;
        else if (payload.description)
            message = payload.description;
    }
    catch { /* use type as message */ }
    return {
        id: e.id,
        timestamp: e.created_at,
        severity: e.severity,
        agent: e.agent_id || '-',
        message,
    };
}
function readInitial(dbPath) {
    try {
        const store = new state_store_1.StateStore(dbPath);
        const recent = store.getRecentEvents(MAX_EVENTS);
        if (recent.length === 0) {
            return { events: [], notifications: [], lastId: 0, store };
        }
        const events = recent.reverse(); // chronological
        const lastId = events[events.length - 1]?.id ?? 0;
        let notifications = [];
        for (const e of events) {
            if (isNotification(e)) {
                notifications.push(eventToNotification(e));
            }
        }
        if (notifications.length > MAX_NOTIFICATIONS) {
            notifications = notifications.slice(-MAX_NOTIFICATIONS);
        }
        return { events, notifications, lastId, store };
    }
    catch {
        return { events: [], notifications: [], lastId: 0, store: null };
    }
}
function useEventBus(dbPath) {
    // Synchronous initial read — data ready before first paint
    const initialRef = (0, react_1.useRef)(readInitial(dbPath));
    const storeRef = (0, react_1.useRef)(initialRef.current.store);
    const lastIdRef = (0, react_1.useRef)(initialRef.current.lastId);
    const eventsRef = (0, react_1.useRef)(initialRef.current.events);
    const notificationsRef = (0, react_1.useRef)(initialRef.current.notifications);
    const [data, setData] = (0, react_1.useState)({
        events: initialRef.current.events,
        notifications: initialRef.current.notifications,
        totalEvents: initialRef.current.lastId,
    });
    (0, react_1.useEffect)(() => {
        const interval = setInterval(() => {
            if (!storeRef.current)
                return;
            try {
                const newEvents = storeRef.current.getEventsSince(lastIdRef.current);
                if (newEvents.length === 0)
                    return;
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
            }
            catch {
                // DB briefly locked
            }
        }, POLL_MS);
        return () => {
            clearInterval(interval);
            try {
                storeRef.current?.close();
            }
            catch { /* ignore */ }
            storeRef.current = null;
        };
    }, [dbPath]);
    return data;
}
//# sourceMappingURL=useEventBus.js.map