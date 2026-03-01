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
export declare function useEventBus(dbPath: string): EventBusData;
export {};
