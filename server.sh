#!/bin/bash

# ---- HANDLE MODE ----
# When ncat accepts a connection, it runs this script with "handle" as $1.
# Whatever this branch prints to stdout goes straight back to the client.
if [ "$1" = "handle" ]; then
    read request

    if [ "$request" = "assignment" ]; then
        html=$(curl -s "https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC")
        section=$(echo "$html" | grep -A 20 'Assignment 2')
        title=$(echo "$section" | grep -o 'Assignment 2' | head -n 1)
        points=$(echo "$section" | grep -o '[0-9]*%' | head -n 1 | tr -d '%')
        dueDate=$(echo "$section" | grep -o 'Due date</b>: [^<]*' | head -n 1 | sed 's/Due date<\/b>: //' | sed 's/ at//')
        topicFull=$(echo "$section" | grep -o 'Programming task - [^<]*' | head -n 1)
        topic=$(echo "$topicFull" | awk '{print $4}')

        jq -n \
            --arg title "$title" \
            --arg topic "$topic" \
            --arg due "$dueDate" \
            --argjson points "$points" \
            '{title: $title, topic: $topic, due_date: $due, points: $points}' > assignment.json

        cat assignment.json

    elif [ "$request" = "population" ]; then
        csv=$(curl -s "https://dbr.abs.gov.au/processedData/csv/STE_1.csv" | tr -d '\r')
        header=$(echo "$csv" | head -n 1)
        numCols=$(echo "$header" | awk -F, '{print NF}')
        echo "numCols is: [$numCols]"
        echo "DEBUG numCols=[$numCols]" >&2

        header=$(echo "$csv" | head -n 1)
        dataRow=$(echo "$csv" | grep '^ERP_P_20,')

        > /tmp/popdata.csv

        numCol=$(echo "$header" | awk -F, '{print NF}')
        for i in $(seq 4 "$numCols"); do
            year=$(echo "$header" | awk -F, -v c="$i" '{print $c}')
            pop=$(echo "$dataRow" | awk -F, -v c="$i" '{print $c}')

            if [ -n "$pop" ]; then
                echo "$year,$pop" >> /tmp/popdata.csv
            fi
        done
        
        python3 /root/plot.py

    else
        echo "DEBUG: POI or unknown"
    fi

    exit 0
fi

# ---- STARTUP MODE ----
# Normal run: find IP + port, then launch ncat which re-invokes this script
# in handle mode for each connection.
ipAddr=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
PORT_NUM=1234
SCRIPT_PATH=$(readlink -f "$0")

echo "The server is running at $ipAddr, port=$PORT_NUM"

ncat -lk -p "$PORT_NUM" --sh-exec "bash $SCRIPT_PATH handle"