"use strict";
// tui/hooks/useDaemon.ts — Read daemon status from DB
Object.defineProperty(exports, "__esModule", { value: true });
exports.useDaemon = useDaemon;
const react_1 = require("react");
const daemon_1 = require("../../daemon");
const POLL_MS = 3000;
function readDaemonStatus() {
    try {
        const daemon = new daemon_1.Daemon();
        const status = daemon.status();
        return {
            running: status.running,
            pid: status.pid,
            startedAt: status.startedAt,
            version: status.version,
            pendingTasks: status.pendingTasks,
            lastCheckpoint: status.lastCheckpoint,
        };
    }
    catch {
        return { running: false, pid: null, startedAt: null, version: null, pendingTasks: 0, lastCheckpoint: null };
    }
}
function useDaemon() {
    // Synchronous initial read — data ready before first paint
    const [data, setData] = (0, react_1.useState)(readDaemonStatus);
    (0, react_1.useEffect)(() => {
        const interval = setInterval(() => {
            setData(readDaemonStatus());
        }, POLL_MS);
        return () => { clearInterval(interval); };
    }, []);
    return data;
}
//# sourceMappingURL=useDaemon.js.map