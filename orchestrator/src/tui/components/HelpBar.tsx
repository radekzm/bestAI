// tui/components/HelpBar.tsx — Bottom keyboard shortcuts bar

import React from 'react';
import { Box, Text } from 'ink';
import { colors } from '../theme';

interface Props {
  activePanel: string;
}

const HelpBar: React.FC<Props> = ({ activePanel }) => {
  return (
    <Box borderStyle="single" borderColor="gray" paddingX={1}>
      <Text>
        {colors.info('Tab')} panel {colors.muted('│')} {colors.info('1-4')} jump {colors.muted('│')} {colors.info('Up/Down')} scroll {colors.muted('│')} {colors.info('q')} quit {colors.muted('│')} active: {colors.bold(activePanel)}
      </Text>
    </Box>
  );
};

export default HelpBar;
