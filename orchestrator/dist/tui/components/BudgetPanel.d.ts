import React from 'react';
interface Props {
    tokensUsed: number;
    tokensLimit: number;
    tokensIn: number;
    tokensOut: number;
    routing: Record<string, number>;
    focused: boolean;
}
declare const BudgetPanel: React.FC<Props>;
export default BudgetPanel;
