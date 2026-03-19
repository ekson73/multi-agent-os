#!/bin/bash
while true; do
  OUTPUT=$(python3 cli.py bitbucket get_build_details "{\"build_number\": 1013, \"workspace\": \"acme-org\", \"repo_slug\": \"my-example-api\"}")
  STATE=$(echo "$OUTPUT" | grep '"state":' | head -n 1 | awk -F'"' '{print $4}')
  RESULT=$(echo "$OUTPUT" | grep '"result":' | head -n 1 | awk -F'"' '{print $4}')
  
  if [[ "$STATE" == "COMPLETED" ]]; then
    if [[ "$RESULT" == "SUCCESSFUL" ]]; then
      echo "Pipeline 1013 SUCCESSFUL. Deploy succeeded!"
      break
    else
      echo "Pipeline 1013 FAILED. Check logs."
      break
    fi
  fi
  echo "Pipeline 1013 is $STATE. Sleeping..."
  sleep 30
done
