// tui/components/EventLog.tsx — Scrollable event stream

import React from 'react';
import { Box, Text } from 'ink';
import { colors, severityIcon, formatTimestamp } from '../theme';
import { EventRow } from '../../types';

interface Props {
  events: EventRow[];
  totalEvents: number;
  focused: boolean;
  scrollOffset: number;
}

const VISIBLE_ROWS = 5;

const EventLog: React.FC<Props> = ({ events, totalEvents, focused, scrollOffset }) => {
  // Show most recent events, scrollable
  const startIdx = Math.max(0, events.length - VISIBLE_ROWS - scrollOffset);
  const visible = events.slice(startIdx, startIdx + VISIBLE_ROWS);

  const rangeStart = startIdx + 1;
  const rangeEnd = startIdx + visible.length;

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('EVENTS')} {colors.muted(`(${totalEvents} total, ${rangeStart}-${rangeEnd})`)}</Text>
      {visible.length === 0 && <Text>{colors.muted('  (no events)')}</Text>}
      {visible.map((e) => {
        const ts = formatTimestamp(e.created_at);
        const icon = severityIcon[e.severity] || severityIcon.info;
        const agent = e.agent_id ? ` @${e.agent_id}` : '';
        const task = e.task_id ? ` #${e.task_id.slice(0, 4)}` : '';
        return (
          <Text key={e.id}>
            {colors.muted(ts)} {icon} {e.type}{agent}{task}
          </Text>
        );
      })}
    </Box>
  );
};

export default EventLog;
