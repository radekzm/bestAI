"use strict";
// tui/components/AgentTree.tsx — N-level hierarchy tree with depth + counts
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const react_1 = __importDefault(require("react"));
const ink_1 = require("ink");
const theme_1 = require("../theme");
function buildTree(agents) {
    const byParent = new Map();
    for (const a of agents) {
        const key = a.parentId || '__root__';
        if (!byParent.has(key))
            byParent.set(key, []);
        byParent.get(key).push(a);
    }
    function buildChildren(parentId) {
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
function renderNode(node, prefix, isLast, lines) {
    const connector = prefix === '' ? '' : isLast ? theme_1.tree.last : theme_1.tree.branch;
    const dot = theme_1.statusDot[node.agent.status || 'idle'] || theme_1.statusDot.idle;
    const name = node.agent.name;
    const role = node.agent.role;
    lines.push(`${prefix}${connector}${name} (${role}) ${dot}`);
    const childPrefix = prefix === '' ? '' : prefix + (isLast ? theme_1.tree.space : theme_1.tree.pipe);
    node.children.forEach((child, i) => {
        renderNode(child, childPrefix, i === node.children.length - 1, lines);
    });
}
const AgentTree = ({ agents, maxDepth, agentsByLevel, focused }) => {
    const roots = buildTree(agents);
    const lines = [];
    roots.forEach((root, i) => renderNode(root, '', i === roots.length - 1, lines));
    // Build depth summary: "Depth: 2 | L0:1 L1:3 L2:1"
    const levelCounts = [];
    for (let l = 0; l <= maxDepth; l++) {
        const count = agentsByLevel.get(l)?.length || 0;
        levelCounts.push(`L${l}:${count}`);
    }
    const depthLine = `Depth: ${maxDepth} | ${levelCounts.join(' ')}`;
    return (react_1.default.createElement(ink_1.Box, { flexDirection: "column", borderStyle: "single", borderColor: focused ? 'cyan' : 'gray', paddingX: 1 },
        react_1.default.createElement(ink_1.Text, null, theme_1.colors.header('AGENT HIERARCHY')),
        react_1.default.createElement(ink_1.Text, null, theme_1.colors.muted(depthLine)),
        react_1.default.createElement(ink_1.Text, null, " "),
        lines.map((line, i) => (react_1.default.createElement(ink_1.Text, { key: i }, line)))));
};
exports.default = AgentTree;
//# sourceMappingURL=AgentTree.js.map