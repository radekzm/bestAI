"use strict";
// tui/hooks/useStore.ts — Poll SQLite for agents and tasks
Object.defineProperty(exports, "__esModule", { value: true });
exports.useStore = useStore;
const react_1 = require("react");
const state_store_1 = require("../../state-store");
const POLL_MS = 2000;
function readStore(store) {
    const agents = store.getAllAgents();
    const tasks = store.getAllTasks();
    const byLevel = new Map();
    let maxDepth = 0;
    for (const a of agents) {
        if (!byLevel.has(a.level))
            byLevel.set(a.level, []);
        byLevel.get(a.level).push(a);
        if (a.level > maxDepth)
            maxDepth = a.level;
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
function readInitial(dbPath) {
    try {
        const store = new state_store_1.StateStore(dbPath);
        return { data: readStore(store), store };
    }
    catch {
        return {
            data: { agents: [], tasks: [], agentsByLevel: new Map(), maxDepth: 0, totalAgents: 0, totalTasks: 0 },
            store: null,
        };
    }
}
function useStore(dbPath) {
    // Synchronous initial read — data ready before first paint
    const initialRef = (0, react_1.useRef)(readInitial(dbPath));
    const storeRef = (0, react_1.useRef)(initialRef.current.store);
    const [data, setData] = (0, react_1.useState)(initialRef.current.data);
    (0, react_1.useEffect)(() => {
        // Store already opened in initialRef
        const interval = setInterval(() => {
            const store = storeRef.current;
            if (!store)
                return;
            try {
                setData(readStore(store));
            }
            catch {
                // DB might be locked briefly
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
//# sourceMappingURL=useStore.js.map