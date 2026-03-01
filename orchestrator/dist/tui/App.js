"use strict";
// tui/App.tsx — Root layout with keyboard navigation and panel focus
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importStar(require("react"));
const ink_1 = require("ink");
const StatusBar_1 = __importDefault(require("./components/StatusBar"));
const ConversationPanel_1 = __importDefault(require("./components/ConversationPanel"));
const TaskList_1 = __importDefault(require("./components/TaskList"));
const EventLog_1 = __importDefault(require("./components/EventLog"));
const AgentTree_1 = __importDefault(require("./components/AgentTree"));
const LimitsPanel_1 = __importDefault(require("./components/LimitsPanel"));
const BudgetPanel_1 = __importDefault(require("./components/BudgetPanel"));
const HelpBar_1 = __importDefault(require("./components/HelpBar"));
const useStore_1 = require("./hooks/useStore");
const useEventBus_1 = require("./hooks/useEventBus");
const useBridge_1 = require("./hooks/useBridge");
const useDaemon_1 = require("./hooks/useDaemon");
const PANELS = ['notifications', 'tasks', 'events', 'agents'];
const App = ({ dbPath }) => {
    const { exit } = (0, ink_1.useApp)();
    // Data hooks
    const store = (0, useStore_1.useStore)(dbPath);
    const eventBus = (0, useEventBus_1.useEventBus)(dbPath);
    const bridge = (0, useBridge_1.useBridge)();
    const daemon = (0, useDaemon_1.useDaemon)();
    // Focus state
    const [focusIdx, setFocusIdx] = (0, react_1.useState)(0);
    const activePanel = PANELS[focusIdx];
    // Scroll offsets per panel
    const [scrolls, setScrolls] = (0, react_1.useState)({
        notifications: 0,
        tasks: 0,
        events: 0,
        agents: 0,
    });
    // Task list selected index
    const [taskSelected, setTaskSelected] = (0, react_1.useState)(0);
    const scroll = (0, react_1.useCallback)((delta) => {
        setScrolls((prev) => {
            const current = prev[activePanel];
            const next = Math.max(0, current + delta);
            return { ...prev, [activePanel]: next };
        });
        // Also move task selection cursor if tasks panel is focused
        if (activePanel === 'tasks') {
            setTaskSelected((prev) => {
                const next = prev + delta;
                return Math.max(0, Math.min(store.tasks.length - 1, next));
            });
        }
    }, [activePanel, store.tasks.length]);
    // Keyboard handler
    (0, ink_1.useInput)((input, key) => {
        if (input === 'q') {
            exit();
            return;
        }
        // Tab / Shift+Tab cycling
        if (key.tab) {
            if (key.shift) {
                setFocusIdx((i) => (i - 1 + PANELS.length) % PANELS.length);
            }
            else {
                setFocusIdx((i) => (i + 1) % PANELS.length);
            }
            return;
        }
        // Number keys 1-4 for direct jump
        if (input >= '1' && input <= '4') {
            setFocusIdx(parseInt(input, 10) - 1);
            return;
        }
        // Arrow keys for scrolling
        if (key.upArrow) {
            scroll(-1);
            return;
        }
        if (key.downArrow) {
            scroll(1);
            return;
        }
    });
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", width: "100%" },
        react_1.default.createElement(StatusBar_1.default, { daemon: daemon, totalAgents: store.totalAgents, totalTasks: store.totalTasks, health: bridge.health }),
        react_1.default.createElement(ink_1.Box, { flexDirection: "row", flexGrow: 1 },
            react_1.default.createElement(ink_1.Box, { flexDirection: "column", flexBasis: "50%", flexShrink: 0 },
                react_1.default.createElement(ConversationPanel_1.default, { notifications: eventBus.notifications, focused: activePanel === 'notifications', scrollOffset: scrolls.notifications }),
                react_1.default.createElement(TaskList_1.default, { tasks: store.tasks, focused: activePanel === 'tasks', scrollOffset: scrolls.tasks, selectedIndex: taskSelected }),
                react_1.default.createElement(EventLog_1.default, { events: eventBus.events, totalEvents: eventBus.totalEvents, focused: activePanel === 'events', scrollOffset: scrolls.events })),
            react_1.default.createElement(ink_1.Box, { flexDirection: "column", flexBasis: "50%", flexShrink: 0 },
                react_1.default.createElement(AgentTree_1.default, { agents: store.agents, maxDepth: store.maxDepth, agentsByLevel: store.agentsByLevel, focused: activePanel === 'agents' }),
                react_1.default.createElement(LimitsPanel_1.default, { providerUsed: bridge.providerUsed, focused: false }),
                react_1.default.createElement(BudgetPanel_1.default, { tokensUsed: bridge.tokensUsed, tokensLimit: bridge.tokensLimit, tokensIn: bridge.tokensIn, tokensOut: bridge.tokensOut, routing: bridge.routing, focused: false }))),
        react_1.default.createElement(HelpBar_1.default, { activePanel: activePanel })));
};
exports.default = App;
//# sourceMappingURL=App.js.map