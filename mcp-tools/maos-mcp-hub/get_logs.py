import os
import json
import base64
import urllib.request
from dotenv import load_dotenv

load_dotenv()
username = os.getenv("BITBUCKET_EMAIL")
password = os.getenv("BITBUCKET_APP_PASSWORD") or os.getenv("BITBUCKET_API_TOKEN")

auth_string = f"{username}:{password}"
base64_auth = base64.b64encode(auth_string.encode("utf-8")).decode("utf-8")

# Get steps for pipeline 997
url = "https://api.bitbucket.org/2.0/repositories/acme-org/my-example-api/pipelines/997/steps/"
req = urllib.request.Request(url)
req.add_header("Authorization", f"Basic {base64_auth}")
req.add_header("Accept", "application/json")

uuid = None
try:
    with urllib.request.urlopen(req) as response:
        data = json.loads(response.read().decode("utf-8"))
        for step in data.get("values", []):
            print(f"Step: {step.get('name')} - State: {step.get('state', {}).get('name')} - Result: {step.get('state', {}).get('result', {}).get('name')}")
            if step.get('name') == 'ECR Deploy' or step.get('state', {}).get('result', {}).get('name') == 'FAILED':
                uuid = step.get('uuid')
                print(f"Found failed step UUID: {uuid}")
except Exception as e:
    print(f"Error fetching steps: {e}")

if uuid:
    log_url = f"https://api.bitbucket.org/2.0/repositories/acme-org/my-example-api/pipelines/997/steps/{uuid}/log"
    print(f"\nFetching logs for UUID: {uuid}")
    log_req = urllib.request.Request(log_url)
    log_req.add_header("Authorization", f"Basic {base64_auth}")
    log_req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(log_req) as response:
            print(response.read().decode("utf-8"))
    except Exception as e:
        print(f"Error fetching log: {e}")
