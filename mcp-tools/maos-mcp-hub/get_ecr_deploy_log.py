import sys
import asyncio
from pathlib import Path
from dotenv import load_dotenv

sys.path.insert(0, str(Path(".")))
load_dotenv()

from lib.bitbucket.client import BitbucketPipelineClient

async def main():
    try:
        client = BitbucketPipelineClient(repo_slug="vek-servicos/vks-jss-sales-api")
        steps_data = await client.get_pipeline_steps(997)
        step_uuid = None
        for step in steps_data.get("values", []):
            if step.get("name") == "ECR Deploy":
                step_uuid = step.get("uuid")
                break
                
        if step_uuid:
            print(f"Fetching log for ECR Deploy (UUID: {step_uuid})")
            log = await client.get_step_log(997, step_uuid)
            print("====== LOG ======")
            print(log)
            print("=================")
        else:
            print("Step 'ECR Deploy' not found.")
            for step in steps_data.get("values", []):
                print(f"Available step: {step.get('name')}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    asyncio.run(main())
