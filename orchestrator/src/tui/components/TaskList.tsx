// tui/components/TaskList.tsx — Scrollable task queue with status symbols

import React from 'react';
import { Box, Text } from 'ink';
import { colors, taskSymbol, shortId, truncate } from '../theme';
import { OrchestratorTask } from '../../types';

interface Props {
  tasks: OrchestratorTask[];
  focused: boolean;
  scrollOffset: number;
  selectedIndex: number;
}

const VISIBLE_ROWS = 5;

const TaskList: React.FC<Props> = ({ tasks, focused, scrollOffset, selectedIndex }) => {
  const visible = tasks.slice(scrollOffset, scrollOffset + VISIBLE_ROWS);

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('TASKS')} {colors.muted(`(${tasks.length} total)`)}</Text>
      {visible.length === 0 && <Text>{colors.muted('  (no tasks)')}</Text>}
      {visible.map((t, i) => {
        const idx = scrollOffset + i;
        const sym = taskSymbol[t.status] || taskSymbol.pending;
        const agent = t.assignedAgent ? ` → ${t.assignedAgent}` : '';
        const line = `${sym} ${shortId(t.id)} ${truncate(t.description, 22)}${agent}`;
        const isSelected = focused && idx === selectedIndex;
        return (
          <Text key={t.id}>{isSelected ? colors.inverse(line) : line}</Text>
        );
      })}
    </Box>
  );
};

export default TaskList;
