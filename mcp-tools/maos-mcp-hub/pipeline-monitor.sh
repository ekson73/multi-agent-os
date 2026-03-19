#!/bin/bash
while true; do
  OUTPUT=$(python3 cli.py bitbucket get_build_details "{\"build_number\": 1011, \"workspace\": \"acme-org\", \"repo_slug\": \"my-example-api\"}")
  STATE=$(echo "$OUTPUT" | grep '"state":' | head -n 1 | awk -F'"' '{print $4}')
  RESULT=$(echo "$OUTPUT" | grep '"result":' | head -n 1 | awk -F'"' '{print $4}')
  
  if [[ "$STATE" == "COMPLETED" ]]; then
    if [[ "$RESULT" == "SUCCESSFUL" ]]; then
      echo "Pipeline 1011 SUCCESSFUL. Merging PR 3..."
      python3 cli.py bitbucket merge_pull_request '{"pr_id": 3, "workspace": "acme-org", "repo_slug": "my-example-api"}'
      break
    else
      echo "Pipeline 1011 FAILED. Cannot merge PR."
      break
    fi
  fi
  echo "Pipeline 1011 is $STATE. Sleeping..."
  sleep 30
done
