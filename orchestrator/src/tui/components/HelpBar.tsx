// tui/components/HelpBar.tsx — Context-sensitive keyboard shortcuts bar

import React from 'react';
import { Box, Text } from 'ink';
import { colors } from '../theme';

interface Props {
  activePanel: string;
  inputMode?: boolean;
}

const HelpBar: React.FC<Props> = ({ activePanel, inputMode = false }) => {
  if (inputMode) {
    // Input mode: show send/cancel hints
    return (
      <Box borderStyle="single" borderColor="gray" paddingX={1}>
        <Text>
          {colors.info('Enter')} send {colors.muted('│')} {colors.info('Esc')} cancel {colors.muted('│')} {colors.muted('typing...')}
        </Text>
      </Box>
    );
  }

  // Navigation mode
  const chatHint = activePanel === 'conversation'
    ? ` ${colors.muted('│')} ${colors.info('Enter')} chat`
    : '';

  return (
    <Box borderStyle="single" borderColor="gray" paddingX={1}>
      <Text>
        {colors.info('Tab')} panel {colors.muted('│')} {colors.info('1-4')} jump {colors.muted('│')} {colors.info('Up/Down')} scroll {colors.muted('│')} {colors.info('q')} quit{chatHint} {colors.muted('│')} active: {colors.bold(activePanel)}
      </Text>
    </Box>
  );
};

export default HelpBar;
