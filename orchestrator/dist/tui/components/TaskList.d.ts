import React from 'react';
import { OrchestratorTask } from '../../types';
interface Props {
    tasks: OrchestratorTask[];
    focused: boolean;
    scrollOffset: number;
    selectedIndex: number;
}
declare const TaskList: React.FC<Props>;
export default TaskList;
