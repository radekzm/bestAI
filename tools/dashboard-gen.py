import json
import os
import sys
from datetime import datetime

def generate_html(output_path):
    events_log = ".claude/events.jsonl"
    events = []
    if os.path.exists(events_log):
        with open(events_log, 'r') as f:
            for line in f:
                try: events.append(json.loads(line))
                except: pass

    # Data aggregation
    total_events = len(events)
    blocks = len([e for e in events if e.get("type") == "BLOCK"])
    compliance_score = int((total_events - blocks) * 100 / total_events) if total_events > 0 else 100

    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>bestAI Swarm Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {{ background-color: #1e1e2e; color: #abb2bf; }}
        .card {{ background-color: #282c34; border: 1px solid #44475a; }}
    </text>
</head>
<body class="p-8">
    <div class="max-w-6xl mx-auto">
        <header class="flex justify-between items-center mb-8">
            <h1 class="text-3xl font-bold text-blue-400">🛸 bestAI Swarm Dashboard</h1>
            <div class="text-sm">Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
        </header>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
            <div class="card p-6 rounded-xl shadow-lg text-center">
                <div class="text-sm uppercase mb-2">Compliance Score</div>
                <div class="text-5xl font-bold {'text-green-400' if compliance_score > 80 else 'text-red-400'}">{compliance_score}%</div>
            </div>
            <div class="card p-6 rounded-xl shadow-lg text-center">
                <div class="text-sm uppercase mb-2">Total Hook Events</div>
                <div class="text-5xl font-bold text-blue-400">{total_events}</div>
            </div>
            <div class="card p-6 rounded-xl shadow-lg text-center">
                <div class="text-sm uppercase mb-2">Active Blocks</div>
                <div class="text-5xl font-bold text-red-400">{blocks}</div>
            </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div class="card p-6 rounded-xl shadow-lg">
                <h2 class="text-xl font-bold mb-4">Security Incidents</h2>
                <canvas id="incidentChart"></canvas>
            </div>
            <div class="card p-6 rounded-xl shadow-lg">
                <h2 class="text-xl font-bold mb-4">Recent Events</h2>
                <div class="overflow-y-auto max-h-64">
                    {"".join([f'<div class="text-xs border-b border-gray-700 py-2">[{e["timestamp"]}] <b>{e["hook"]}</b>: {e["type"]}</div>' for e in events[-10:]][::-1])}
                </div>
            </div>
        </div>
    </div>

    <script>
        const ctx = document.getElementById('incidentChart').getContext('2d');
        new Chart(ctx, {{
            type: 'doughnut',
            data: {{
                labels: ['Allowed', 'Blocked'],
                datasets: [{{
                    data: [{total_events - blocks}, {blocks}],
                    backgroundColor: ['#98c379', '#e06c75'],
                    borderWidth: 0
                }}]
            }},
            options: {{ responsive: true, plugins: {{ legend: {{ position: 'bottom', labels: {{ color: '#abb2bf' }} }} }} }}
        }});
    </script>
</body>
</html>"""
    
    with open(output_path, 'w') as f:
        f.write(html_content)

if __name__ == "__main__":
    out_dir = ".bestai/dashboard"
    os.makedirs(out_dir, exist_ok=True)
    generate_html(os.path.join(out_dir, "index.html"))
    print(f"Dashboard generated at {out_dir}/index.html")
