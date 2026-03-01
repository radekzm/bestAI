import React from 'react';
import { AgentConfig } from '../../types';
interface Props {
    agents: AgentConfig[];
    maxDepth: number;
    agentsByLevel: Map<number, AgentConfig[]>;
    focused: boolean;
}
declare const AgentTree: React.FC<Props>;
export default AgentTree;
