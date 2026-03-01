import React from 'react';
import { DaemonData } from '../hooks/useDaemon';
interface Props {
    daemon: DaemonData;
    totalAgents: number;
    totalTasks: number;
    health: string;
}
declare const StatusBar: React.FC<Props>;
export default StatusBar;
