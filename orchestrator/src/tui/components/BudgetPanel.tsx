// tui/components/BudgetPanel.tsx — Token budget with progress bar

import React from 'react';
import { Box, Text } from 'ink';
import { colors, formatTokens, progressBar } from '../theme';

interface Props {
  tokensUsed: number;
  tokensLimit: number;
  tokensIn: number;
  tokensOut: number;
  routing: Record<string, number>;
  focused: boolean;
}

const BudgetPanel: React.FC<Props> = ({ tokensUsed, tokensLimit, tokensIn, tokensOut, routing, focused }) => {
  const ratio = tokensLimit > 0 ? tokensUsed / tokensLimit : 0;
  const percent = Math.round(ratio * 100);
  const bar = progressBar(ratio, 8);

  const barColored = percent > 80 ? colors.error(bar) : percent > 50 ? colors.warning(bar) : colors.success(bar);

  const routingParts = Object.entries(routing)
    .map(([vendor, count]) => `${vendor}:${count}`)
    .join(' ');

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('BUDGET')}</Text>
      <Text>
        tokens: {formatTokens(tokensUsed)}/{formatTokens(tokensLimit)} {barColored} {percent}%
      </Text>
      <Text>
        {colors.label('in:')}{formatTokens(tokensIn)} {colors.label('out:')}{formatTokens(tokensOut)}
      </Text>
      {routingParts.length > 0 && (
        <Text>{colors.label('routing:')} {colors.muted(routingParts)}</Text>
      )}
    </Box>
  );
};

export default BudgetPanel;
