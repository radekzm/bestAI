// tui/App.tsx — Root layout with keyboard navigation and panel focus

import React, { useState, useCallback } from 'react';
import { Box, useInput, useApp } from 'ink';
import StatusBar from './components/StatusBar';
import ConversationPanel from './components/ConversationPanel';
import TaskList from './components/TaskList';
import EventLog from './components/EventLog';
import AgentTree from './components/AgentTree';
import LimitsPanel from './components/LimitsPanel';
import BudgetPanel from './components/BudgetPanel';
import HelpBar from './components/HelpBar';
import { useStore } from './hooks/useStore';
import { useEventBus } from './hooks/useEventBus';
import { useBridge } from './hooks/useBridge';
import { useDaemon } from './hooks/useDaemon';

const PANELS = ['notifications', 'tasks', 'events', 'agents'] as const;
type PanelName = typeof PANELS[number];

interface Props {
  dbPath: string;
}

const App: React.FC<Props> = ({ dbPath }) => {
  const { exit } = useApp();

  // Data hooks
  const store = useStore(dbPath);
  const eventBus = useEventBus(dbPath);
  const bridge = useBridge();
  const daemon = useDaemon();

  // Focus state
  const [focusIdx, setFocusIdx] = useState(0);
  const activePanel = PANELS[focusIdx];

  // Scroll offsets per panel
  const [scrolls, setScrolls] = useState<Record<PanelName, number>>({
    notifications: 0,
    tasks: 0,
    events: 0,
    agents: 0,
  });

  // Task list selected index
  const [taskSelected, setTaskSelected] = useState(0);

  const scroll = useCallback((delta: number) => {
    setScrolls((prev) => {
      const current = prev[activePanel];
      const next = Math.max(0, current + delta);
      return { ...prev, [activePanel]: next };
    });

    // Also move task selection cursor if tasks panel is focused
    if (activePanel === 'tasks') {
      setTaskSelected((prev) => {
        const next = prev + delta;
        return Math.max(0, Math.min(store.tasks.length - 1, next));
      });
    }
  }, [activePanel, store.tasks.length]);

  // Keyboard handler
  useInput((input, key) => {
    if (input === 'q') {
      exit();
      return;
    }

    // Tab / Shift+Tab cycling
    if (key.tab) {
      if (key.shift) {
        setFocusIdx((i) => (i - 1 + PANELS.length) % PANELS.length);
      } else {
        setFocusIdx((i) => (i + 1) % PANELS.length);
      }
      return;
    }

    // Number keys 1-4 for direct jump
    if (input >= '1' && input <= '4') {
      setFocusIdx(parseInt(input, 10) - 1);
      return;
    }

    // Arrow keys for scrolling
    if (key.upArrow) {
      scroll(-1);
      return;
    }
    if (key.downArrow) {
      scroll(1);
      return;
    }
  });

  return (
    <Box flexDirection="column" width="100%">
      {/* Top: Status bar */}
      <StatusBar
        daemon={daemon}
        totalAgents={store.totalAgents}
        totalTasks={store.totalTasks}
        health={bridge.health}
      />

      {/* Main: 2-column layout */}
      <Box flexDirection="row" flexGrow={1}>
        {/* Left column */}
        <Box flexDirection="column" flexBasis="50%" flexShrink={0}>
          <ConversationPanel
            notifications={eventBus.notifications}
            focused={activePanel === 'notifications'}
            scrollOffset={scrolls.notifications}
          />
          <TaskList
            tasks={store.tasks}
            focused={activePanel === 'tasks'}
            scrollOffset={scrolls.tasks}
            selectedIndex={taskSelected}
          />
          <EventLog
            events={eventBus.events}
            totalEvents={eventBus.totalEvents}
            focused={activePanel === 'events'}
            scrollOffset={scrolls.events}
          />
        </Box>

        {/* Right column */}
        <Box flexDirection="column" flexBasis="50%" flexShrink={0}>
          <AgentTree
            agents={store.agents}
            maxDepth={store.maxDepth}
            agentsByLevel={store.agentsByLevel}
            focused={activePanel === 'agents'}
          />
          <LimitsPanel
            providerUsed={bridge.providerUsed}
            focused={false}
          />
          <BudgetPanel
            tokensUsed={bridge.tokensUsed}
            tokensLimit={bridge.tokensLimit}
            tokensIn={bridge.tokensIn}
            tokensOut={bridge.tokensOut}
            routing={bridge.routing}
            focused={false}
          />
        </Box>
      </Box>

      {/* Bottom: Help bar */}
      <HelpBar activePanel={activePanel} />
    </Box>
  );
};

export default App;
