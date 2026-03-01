// tui/components/ConversationPanel.tsx — Push notifications from agents

import React from 'react';
import { Box, Text } from 'ink';
import { colors, severityIcon, formatTimestamp, truncate } from '../theme';
import { Notification } from '../hooks/useEventBus';

interface Props {
  notifications: Notification[];
  focused: boolean;
  scrollOffset: number;
}

const VISIBLE_ROWS = 5;

const ConversationPanel: React.FC<Props> = ({ notifications, focused, scrollOffset }) => {
  const startIdx = Math.max(0, notifications.length - VISIBLE_ROWS - scrollOffset);
  const visible = notifications.slice(startIdx, startIdx + VISIBLE_ROWS);

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('NOTIFICATIONS')}</Text>
      {visible.length === 0 && <Text>{colors.muted('  (no notifications)')}</Text>}
      {visible.map((n) => {
        const ts = formatTimestamp(n.timestamp);
        const icon = severityIcon[n.severity] || severityIcon.info;
        const agent = n.agent !== '-' ? `@${n.agent}: ` : '';
        return (
          <Text key={n.id}>
            {colors.muted(ts)} {icon} {colors.info(agent)}{truncate(n.message, 30)}
          </Text>
        );
      })}
    </Box>
  );
};

export default ConversationPanel;
