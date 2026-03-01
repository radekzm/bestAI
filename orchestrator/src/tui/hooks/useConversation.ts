// tui/hooks/useConversation.ts — Send user messages as tasks via SQLite

import { useRef, useEffect, useCallback } from 'react';
import { StateStore } from '../../state-store';
import crypto from 'crypto';

interface UseConversationResult {
  sendMessage: (text: string) => void;
}

export function useConversation(dbPath: string): UseConversationResult {
  const storeRef = useRef<StateStore | null>(null);

  // Open a writable store on mount
  if (!storeRef.current) {
    try {
      storeRef.current = new StateStore(dbPath);
    } catch {
      // DB may not exist yet
    }
  }

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      try { storeRef.current?.close(); } catch { /* ignore */ }
      storeRef.current = null;
    };
  }, [dbPath]);

  const sendMessage = useCallback((text: string) => {
    const store = storeRef.current;
    if (!store || !text.trim()) return;

    const taskId = crypto.randomUUID();
    const now = Date.now();

    // Create a pending task — daemon's 1s loop will pick it up
    store.createTask({
      id: taskId,
      description: text.trim(),
      status: 'pending',
      dependencies: [],
      createdAt: now,
      updatedAt: now,
    });

    // Insert user:message event — shows in conversation panel
    store.insertEvent('user:message', 'info', undefined, taskId, { message: text.trim() });

    // Insert task:created event — also shows in conversation
    store.insertEvent('task:created', 'info', undefined, taskId, { description: text.trim() });
  }, []);

  return { sendMessage };
}
