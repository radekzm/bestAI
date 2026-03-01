// tui/components/AgentTree.tsx — N-level hierarchy tree with depth + counts

import React from 'react';
import { Box, Text } from 'ink';
import { colors, statusDot, tree as treeSym } from '../theme';
import { AgentConfig } from '../../types';

interface Props {
  agents: AgentConfig[];
  maxDepth: number;
  agentsByLevel: Map<number, AgentConfig[]>;
  focused: boolean;
}

interface TreeNode {
  agent: AgentConfig;
  children: TreeNode[];
}

function buildTree(agents: AgentConfig[]): TreeNode[] {
  const byParent = new Map<string | undefined, AgentConfig[]>();
  for (const a of agents) {
    const key = a.parentId || '__root__';
    if (!byParent.has(key)) byParent.set(key, []);
    byParent.get(key)!.push(a);
  }

  function buildChildren(parentId: string | undefined): TreeNode[] {
    const key = parentId || '__root__';
    const children = byParent.get(key) || [];
    return children.map((a) => ({
      agent: a,
      children: buildChildren(a.id),
    }));
  }

  // Roots are agents with no parent or parent not in the list
  const agentIds = new Set(agents.map((a) => a.id));
  const roots = agents.filter((a) => !a.parentId || !agentIds.has(a.parentId));
  return roots.map((a) => ({
    agent: a,
    children: buildChildren(a.id),
  }));
}

function renderNode(node: TreeNode, prefix: string, isLast: boolean, lines: string[]): void {
  const connector = prefix === '' ? '' : isLast ? treeSym.last : treeSym.branch;
  const dot = statusDot[node.agent.status || 'idle'] || statusDot.idle;
  const name = node.agent.name;
  const role = node.agent.role;
  lines.push(`${prefix}${connector}${name} (${role}) ${dot}`);

  const childPrefix = prefix === '' ? '' : prefix + (isLast ? treeSym.space : treeSym.pipe);
  node.children.forEach((child, i) => {
    renderNode(child, childPrefix, i === node.children.length - 1, lines);
  });
}

const AgentTree: React.FC<Props> = ({ agents, maxDepth, agentsByLevel, focused }) => {
  const roots = buildTree(agents);
  const lines: string[] = [];
  roots.forEach((root, i) => renderNode(root, '', i === roots.length - 1, lines));

  // Build depth summary: "Depth: 2 | L0:1 L1:3 L2:1"
  const levelCounts: string[] = [];
  for (let l = 0; l <= maxDepth; l++) {
    const count = agentsByLevel.get(l)?.length || 0;
    levelCounts.push(`L${l}:${count}`);
  }
  const depthLine = `Depth: ${maxDepth} | ${levelCounts.join(' ')}`;

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={focused ? 'cyan' : 'gray'} paddingX={1}>
      <Text>{colors.header('AGENT HIERARCHY')}</Text>
      <Text>{colors.muted(depthLine)}</Text>
      <Text> </Text>
      {lines.map((line, i) => (
        <Text key={i}>{line}</Text>
      ))}
    </Box>
  );
};

export default AgentTree;
