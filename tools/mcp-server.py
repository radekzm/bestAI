import json
import sys
import os

def get_project_state():
    try:
        with open(".bestai/GPS.json", "r") as f:
            return json.load(f)
    except:
        return {"error": "GPS.json not found"}

def handle_request(request):
    method = request.get("method")
    if method == "get_project_state":
        return {"result": get_project_state()}
    elif method == "get_version":
        return {"result": "bestAI v1.3.0 (MCP Edition)"}
    else:
        return {"error": "Method not supported"}

def main():
    print("bestAI MCP Server starting...", file=sys.stderr)
    # Simple JSON-RPC-like interface over stdio
    for line in sys.stdin:
        try:
            req = json.loads(line)
            res = handle_request(req)
            print(json.dumps(res))
            sys.stdout.flush()
        except:
            pass

if __name__ == "__main__":
    main()
