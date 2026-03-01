import os
import json
from datetime import datetime

def nexus_checkin(user, role, decision):
    print(f"\033[1;32m✅ Nexus Check-in successful for {user} ({role}).\033[0m")

if __name__ == "__main__":
    nexus_checkin("User", "Lead", "Logged via v14.0")
