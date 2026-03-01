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
export declare function useBridge(): BridgeData;
