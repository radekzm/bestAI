import time
import sys
import os

def print_conductor(text, delay=0.03):
    print("\033[1;34mCONDUCTOR >\033[0m ", end="")
    for char in text:
        sys.stdout.write(char)
        sys.stdout.flush()
        time.sleep(delay)
    print()

def print_agent(agent, text):
    colors = {"GEMINI": "\033[1;32m", "CLAUDE": "\033[1;31m", "USER": "\033[1;33m"}
    print(f"{colors.get(agent, '')}[{agent}]\033[0m {text}")

def run_demo():
    os.system('clear')
    print("\033[1;36m=== bestAI v10.0 'Living Swarm' Official Demo ===\033[0m\n")
    
    print_agent("USER", "I need to migrate our legacy Auth system to JWT. Can you start researching the existing code and prepare a plan?")
    time.sleep(1)
    
    print_conductor("Acknowledged. I am assembling the Syndicate.")
    print_conductor("🛰️  Dispatching GEMINI (Investigator) to scan the legacy /src/auth folder.")
    print_conductor("Gemini is working in the background. While we wait, what should be the name of the new JWT secret key in our config?")
    
    time.sleep(2)
    print_agent("GEMINI", "(Background) Scanning 45 files... Generating T3-summary... [SILENT]")
    
    print_agent("USER", "Let's call it 'SYNDICATE_AUTH_SECRET'.")
    time.sleep(1)
    
    print_conductor("Perfect. I've updated .bestai/GPS.json with the secret name.")
    
    # Simulate async completion
    print("\n\033[1;34m[CONDUCTOR] 🔔 IMPORTANT UPDATE from GEMINI:\033[0m")
    print("Legacy Auth uses MD5 hashing (Critical Security Risk). I've stored the full analysis in Research Vault.")
    
    time.sleep(1)
    print_conductor("Since Gemini found MD5, I am now dispatching CLAUDE (Lead Architect) to build the new Argon2-based JWT handler.")
    print_conductor("Claude is now coding in branch 'feat-jwt-auth'. You can continue talking to me.")
    
    time.sleep(3)
    print_agent("CLAUDE", "(Background) Writing jwt_handler.py... Applying check-frozen.sh... [SILENT]")
    
    print("\n\033[1;34m[CONDUCTOR] 🏁 MILESTONE REACHED:\033[0m New JWT Auth implemented and verified.")
    print_conductor("The Syndicate has successfully completed the migration. Total tokens saved via Vault: 45,200.")
    print_conductor("Ready for your next command, Boss.")

if __name__ == "__main__":
    run_demo()
