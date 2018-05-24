#!/bin/bash
# 
# Data Protection RESTful API (uses “jq” to parse and process the JSON responses). 
# 
# Call the “execute” API with a specific job and identifier 
# The “execute” API responds with an HTTP code (200 for no errors), and a JSON packet containing both a unique run identification number and a status. 
# Jobs return a “PENDING” status if they are submitted successfully. The script parses this JSON packet and remembers the run identification number.
# The script then polls the “runs” API with the unique job run identification number in order to watch the progression of the job’s status. 
# The job progresses from “PENDING” to “ACCEPTED” to “RUNNING”. 
# The script watches for an end status (either “SUCCESS” or “FAILED”). 
# The script returns a standard 0 for success and non-zero for failure.
# 
# Edit the following environment variable values in the script file 
# 
# JOB (Job ID, taken from the Publisher UI)
# OUTPUT_PDD (PDD ID, taken from the Publisher UI)
# PUBLISHER_URL (https:// url of the Publisher UI)
# USERNAME (username of the user you wish to authenticate)
# PASSWORD (password of the user you wish to authenticate)
# 
JOB="JOBID"
OUTPUT_PDD="OUTPUT_PDD"

PUBLISHER_URL="PUBLISHER_UI"

USERNAME="username"
PASSWORD="password"

function makeExecuteCall() {
    local RESPONSE=$( curl --user ${1}:${2} --silent -H "Content-Type: application/json" -X POST -d '{"protectedDataDomainId": "'${3}'", "tables" : ["test", "test2"] }' ${4}/api/v2/jobs/${5}/execute )
    
    echo ${RESPONSE}
}

function makeStatusCall() {
    local RESPONSE=$( curl --user ${1}:${2} --silent -X GET ${3}/api/v2/runs/${4} )
    
    echo ${RESPONSE}
}

echo "Executing job ${JOB} into PDD ${OUTPUT_PDD}"

BODY=$(makeExecuteCall ${USERNAME} ${PASSWORD} ${OUTPUT_PDD} ${PUBLISHER_URL} ${JOB})

STATE=$( echo "${BODY}" | jq -r '.state' )
RUN_ID=$( echo "${BODY}" | jq -r '.runId' )

echo "Job is running with ID ${RUN_ID}"

if [[ -z ${RUN_ID} || "${STATE}" != "PENDING" ]]; then
    echo "Job did not execute properly."
    exit 1
fi

while [[ "${STATE}" == "PENDING" ]]; do
    echo "Job status is ${STATE}"
    sleep 1
    BODY=$( makeStatusCall ${USERNAME} ${PASSWORD} ${PUBLISHER_URL} ${RUN_ID} )
    STATE=$( echo "${BODY}" | jq -r '.state' )
done

while [[ "${STATE}" != "PENDING" ]]; do
    echo "Job status is ${STATE}."
    sleep 1
    BODY=$(makeStatusCall ${USERNAME} ${PASSWORD} ${PUBLISHER_URL} ${RUN_ID})
    STATE=$(echo "${BODY}" | jq -r '.state')
    
    if [[ "${STATE}" == "SUCCESS" ]]; then
        echo "Job has completed."
        exit 0
    fi
    
    if [[ "${STATE}" == "FAILED" ]]; then
        echo "Job has failed during operation."
        exit 1
    fi
done

exit 0
