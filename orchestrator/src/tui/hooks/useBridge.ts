// tui/hooks/useBridge.ts — Call cockpit.sh for budget/limits/health data

import { useState, useEffect, useRef } from 'react';
import { BestAIBridge } from '../../bridge';

export interface BridgeData {
  health: string;
  tokensUsed: number;
  tokensLimit: number;
  tokensIn: number;
  tokensOut: number;
  routing: Record<string, number>;
  providerUsed: Record<string, number>;
  loaded: boolean;
}

const POLL_MS = 10_000;

const EMPTY: BridgeData = {
  health: 'OK',
  tokensUsed: 0,
  tokensLimit: 200_000,
  tokensIn: 0,
  tokensOut: 0,
  routing: {},
  providerUsed: {},
  loaded: false,
};

export function useBridge(): BridgeData {
  const [data, setData] = useState<BridgeData>(EMPTY);
  const bridgeRef = useRef<BestAIBridge | null>(null);

  useEffect(() => {
    bridgeRef.current = new BestAIBridge();

    async function poll() {
      const bridge = bridgeRef.current;
      if (!bridge) return;

      try {
        const result = await bridge.callCockpit();
        if (!result.success) return;

        const parsed = parseCockpitOutput(result.stdout);
        setData({ ...parsed, loaded: true });
      } catch {
        // cockpit.sh not available or failed
      }
    }

    poll();
    const interval = setInterval(poll, POLL_MS);
    return () => { clearInterval(interval); };
  }, []);

  return data;
}

function parseCockpitOutput(stdout: string): Omit<BridgeData, 'loaded'> {
  try {
    const json = JSON.parse(stdout);
    return {
      health: json.health || 'OK',
      tokensUsed: json.tokens_used ?? json.tokensUsed ?? 0,
      tokensLimit: json.tokens_limit ?? json.tokensLimit ?? 200_000,
      tokensIn: json.tokens_in ?? json.tokensIn ?? 0,
      tokensOut: json.tokens_out ?? json.tokensOut ?? 0,
      routing: json.routing || {},
      providerUsed: json.provider_used || json.providerUsed || {},
    };
  } catch {
    // Non-JSON output — try to extract key-value pairs
    const result: Omit<BridgeData, 'loaded'> = {
      health: 'OK',
      tokensUsed: 0,
      tokensLimit: 200_000,
      tokensIn: 0,
      tokensOut: 0,
      routing: {},
      providerUsed: {},
    };

    const lines = stdout.split('\n');
    for (const line of lines) {
      if (line.includes('health')) {
        if (line.includes('FAIL')) result.health = 'FAIL';
        else if (line.includes('WARN')) result.health = 'WARN';
      }
    }
    return result;
  }
}
