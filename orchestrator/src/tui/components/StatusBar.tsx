// tui/components/StatusBar.tsx — Top bar: daemon status, agents, tasks, health

import React from 'react';
import { Box, Text } from 'ink';
import { colors, statusDot, healthLabel, formatUptime } from '../theme';
import { DaemonData } from '../hooks/useDaemon';

interface Props {
  daemon: DaemonData;
  totalAgents: number;
  totalTasks: number;
  health: string;
}

const StatusBar: React.FC<Props> = ({ daemon, totalAgents, totalTasks, health }) => {
  const dot = daemon.running ? statusDot.idle : statusDot.stopped;
  const pid = daemon.pid ? `PID ${daemon.pid}` : 'no PID';
  const uptime = formatUptime(daemon.startedAt);
  const hLabel = healthLabel[health] || healthLabel.OK;

  return (
    <Box borderStyle="single" borderColor="cyan" paddingX={1}>
      <Text>{colors.header(' bestAI Orchestrator ')}</Text>
      <Text> {dot} daemon {pid} up {uptime}</Text>
      <Text> {colors.muted('│')} agents: {colors.value(String(totalAgents))}</Text>
      <Text> {colors.muted('│')} tasks: {colors.value(String(totalTasks))}</Text>
      <Text> {colors.muted('│')} health: {hLabel}</Text>
    </Box>
  );
};

export default StatusBar;
