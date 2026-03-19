import os
import json
import base64
import urllib.request
from dotenv import load_dotenv

load_dotenv()
username = os.getenv("BITBUCKET_EMAIL")
password = os.getenv("BITBUCKET_APP_PASSWORD") or os.getenv("BITBUCKET_API_TOKEN")

# Create auth header
auth_string = f"{username}:{password}"
base64_auth = base64.b64encode(auth_string.encode("utf-8")).decode("utf-8")

url = "https://api.bitbucket.org/2.0/repositories/acme-org/my-example-api/pullrequests?state=OPEN"
req = urllib.request.Request(url)
req.add_header("Authorization", f"Basic {base64_auth}")
req.add_header("Accept", "application/json")

try:
    with urllib.request.urlopen(req) as response:
        print("Status Code:", response.getcode())
        data = json.loads(response.read().decode("utf-8"))
        prs = data.get("values", [])
        if not prs:
            print("No open pull requests found.")
        for pr in prs:
            print("PR ID:", pr.get("id"))
            print("Title:", pr.get("title"))
            print("State:", pr.get("state"))
            print("Source:", pr.get("source", {}).get("branch", {}).get("name"))
            print("Destination:", pr.get("destination", {}).get("branch", {}).get("name"))
            print("URL:", pr.get("links", {}).get("html", {}).get("href"))
            print("---")
except Exception as e:
    print(f"Error: {e}")
