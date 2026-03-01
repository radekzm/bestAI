// tui/components/ConversationPanel.tsx — Bidirectional conversation panel

import React, { useState, useEffect } from 'react';
import { Box, Text, useInput } from 'ink';
import { colors, getSenderColor, formatTimestamp, truncate } from '../theme';
import { Notification } from '../hooks/useEventBus';

interface Props {
  notifications: Notification[];
  focused: boolean;
  scrollOffset: number;
  inputMode: boolean;
  onSend: (text: string) => void;
  onExitInput: () => void;
}

const VISIBLE_ROWS = 7;

function renderMessage(n: Notification, maxWidth: number): React.ReactElement {
  const ts = formatTimestamp(n.timestamp);
  const colorFn = getSenderColor(n.agent === 'user' ? 'user' : n.agent === '-' ? 'system' : 'agent');

  let prefix: string;
  if (n.agent === 'user') {
    prefix = '> ';
  } else if (n.agent === '-') {
    prefix = '[i] ';
  } else {
    prefix = `@${n.agent}: `;
  }

  // Reserve space for timestamp + spacing + prefix
  const overhead = ts.length + 1 + prefix.length;
  const msgWidth = Math.max(10, maxWidth - overhead);

  return (
    <Text key={n.id}>
      {colors.muted(ts)} {colorFn(prefix)}{truncate(n.message, msgWidth)}
    </Text>
  );
}

const ConversationPanel: React.FC<Props> = ({
  notifications,
  focused,
  scrollOffset,
  inputMode,
  onSend,
  onExitInput,
}) => {
  const [buffer, setBuffer] = useState('');
  const [cursor, setCursor] = useState(0);

  // Auto-exit input mode if panel loses focus
  useEffect(() => {
    if (!focused && inputMode) {
      onExitInput();
    }
  }, [focused, inputMode, onExitInput]);

  // Handle input keys — only active when inputMode AND focused
  useInput((input, key) => {
    // Send message
    if (key.return) {
      if (buffer.trim()) {
        onSend(buffer.trim());
      }
      setBuffer('');
      setCursor(0);
      onExitInput();
      return;
    }

    // Cancel input
    if (key.escape) {
      setBuffer('');
      setCursor(0);
      onExitInput();
      return;
    }

    // Backspace
    if (key.backspace || key.delete) {
      if (cursor > 0) {
        setBuffer((b) => b.slice(0, cursor - 1) + b.slice(cursor));
        setCursor((c) => c - 1);
      }
      return;
    }

    // Left arrow
    if (key.leftArrow) {
      setCursor((c) => Math.max(0, c - 1));
      return;
    }

    // Right arrow
    if (key.rightArrow) {
      setCursor((c) => Math.min(buffer.length, c + 1));
      return;
    }

    // Regular character input
    if (input && !key.ctrl && !key.meta) {
      setBuffer((b) => b.slice(0, cursor) + input + b.slice(cursor));
      setCursor((c) => c + input.length);
    }
  }, { isActive: inputMode && focused });

  // Compute visible messages
  const startIdx = Math.max(0, notifications.length - VISIBLE_ROWS - scrollOffset);
  const visible = notifications.slice(startIdx, startIdx + VISIBLE_ROWS);

  // Render input line with cursor
  const inputLine = inputMode ? (
    <Text>
      {colors.success('> ')}{buffer.slice(0, cursor)}
      {colors.inverse(cursor < buffer.length ? buffer[cursor] : ' ')}
      {buffer.slice(cursor + 1)}
    </Text>
  ) : (
    <Text>{colors.muted(focused ? 'Press Enter to chat...' : '')}</Text>
  );

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('CONVERSATION')}</Text>
      {visible.length === 0 && !inputMode && (
        <Text>{colors.muted('  (no messages)')}</Text>
      )}
      {visible.map((n) => renderMessage(n, 60))}
      {/* Pad empty rows so the panel height stays stable */}
      {Array.from({ length: Math.max(0, VISIBLE_ROWS - visible.length) }).map((_, i) => (
        <Text key={`pad-${i}`}> </Text>
      ))}
      {/* Input separator + line */}
      <Text>{colors.muted('─'.repeat(40))}</Text>
      {inputLine}
    </Box>
  );
};

export default ConversationPanel;
