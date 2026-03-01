import React from 'react';
import { EventRow } from '../../types';
interface Props {
    events: EventRow[];
    totalEvents: number;
    focused: boolean;
    scrollOffset: number;
}
declare const EventLog: React.FC<Props>;
export default EventLog;
