import React from 'react';
import { Notification } from '../hooks/useEventBus';
interface Props {
    notifications: Notification[];
    focused: boolean;
    scrollOffset: number;
}
declare const ConversationPanel: React.FC<Props>;
export default ConversationPanel;
