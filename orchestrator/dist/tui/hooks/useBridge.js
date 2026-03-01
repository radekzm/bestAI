"use strict";
// tui/hooks/useBridge.ts — Call cockpit.sh for budget/limits/health data
Object.defineProperty(exports, "__esModule", { value: true });
exports.useBridge = useBridge;
const react_1 = require("react");
const bridge_1 = require("../../bridge");
const POLL_MS = 10000;
const EMPTY = {
    health: 'OK',
    tokensUsed: 0,
    tokensLimit: 200000,
    tokensIn: 0,
    tokensOut: 0,
    routing: {},
    providerUsed: {},
    loaded: false,
};
function useBridge() {
    const [data, setData] = (0, react_1.useState)(EMPTY);
    const bridgeRef = (0, react_1.useRef)(null);
    (0, react_1.useEffect)(() => {
        bridgeRef.current = new bridge_1.BestAIBridge();
        async function poll() {
            const bridge = bridgeRef.current;
            if (!bridge)
                return;
            try {
                const result = await bridge.callCockpit();
                if (!result.success)
                    return;
                const parsed = parseCockpitOutput(result.stdout);
                setData({ ...parsed, loaded: true });
            }
            catch {
                // cockpit.sh not available or failed
            }
        }
        poll();
        const interval = setInterval(poll, POLL_MS);
        return () => { clearInterval(interval); };
    }, []);
    return data;
}
function parseCockpitOutput(stdout) {
    try {
        const json = JSON.parse(stdout);
        return {
            health: json.health || 'OK',
            tokensUsed: json.tokens_used ?? json.tokensUsed ?? 0,
            tokensLimit: json.tokens_limit ?? json.tokensLimit ?? 200000,
            tokensIn: json.tokens_in ?? json.tokensIn ?? 0,
            tokensOut: json.tokens_out ?? json.tokensOut ?? 0,
            routing: json.routing || {},
            providerUsed: json.provider_used || json.providerUsed || {},
        };
    }
    catch {
        // Non-JSON output — try to extract key-value pairs
        const result = {
            health: 'OK',
            tokensUsed: 0,
            tokensLimit: 200000,
            tokensIn: 0,
            tokensOut: 0,
            routing: {},
            providerUsed: {},
        };
        const lines = stdout.split('\n');
        for (const line of lines) {
            if (line.includes('health')) {
                if (line.includes('FAIL'))
                    result.health = 'FAIL';
                else if (line.includes('WARN'))
                    result.health = 'WARN';
            }
        }
        return result;
    }
}
//# sourceMappingURL=useBridge.js.map