// tui/components/LimitsPanel.tsx — Multi-provider context limits table

import React from 'react';
import { Box, Text } from 'ink';
import { colors, PROVIDER_LIMITS, formatTokens } from '../theme';

interface Props {
  providerUsed: Record<string, number>;
  focused: boolean;
}

const LimitsPanel: React.FC<Props> = ({ providerUsed, focused }) => {
  const providers = Object.keys(PROVIDER_LIMITS);

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('CONTEXT LIMITS')}</Text>
      <Text>
        {colors.label('Provider')}  {colors.label('Short')}  {colors.label('Long')}    {colors.label('Used')}
      </Text>
      {providers.map((p) => {
        const limits = PROVIDER_LIMITS[p];
        const used = providerUsed[p] || 0;
        const name = p.padEnd(9);
        const short = formatTokens(limits.short).padStart(5);
        const long = formatTokens(limits.long).padStart(5);
        const usedStr = formatTokens(used).padStart(5);
        return (
          <Text key={p}>
            {colors.info(name)} {colors.value(short)}  {colors.value(long)}  {used > 0 ? colors.warning(usedStr) : colors.muted(usedStr)}
          </Text>
        );
      })}
    </Box>
  );
};

export default LimitsPanel;
