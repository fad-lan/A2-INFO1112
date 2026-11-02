#!/bin/bash

# ---- HANDLE MODE ----
# When ncat accepts a connection, it runs this script with "handle" as $1.
# Whatever this branch prints to stdout goes straight back to the client.
if [ "$1" = "handle" ]; then
    clientIP="$NCAT_REMOTE_ADDR"
    lockfile="/tmp/lock_$clientIP"

    # if this IP is already being served, reject
    if [ -e "$lockfile" ]; then
        echo "Request rejected: already serving your previous request"
        exit 0
    fi

    # create the lock
    touch "$lockfile"
    trap 'rm -f "$lockfile"' EXIT

    read request
    echo "client IP: $NCAT_REMOTE_ADDR" >&2
    if [ "$request" = "assignment" ]; then
        html=$(curl -sf "https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC")
        status=$?
        if [ "$status" -ne 0 ]; then
            echo "Webpage Error"
            exit 1
        fi
        if [ -z "$html" ]; then
            echo "Webpage Empty"
            exit 1
        fi
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
        csv=$(curl -sf "https://dbr.abs.gov.au/processedData/csv/STE_1.csv")
        status=$?
        if [ "$status" -ne 0 ]; then echo "CSV Error"; exit 1; fi
        csv=$(echo "$csv" | tr -d '\r')
        header=$(echo "$csv" | head -n 1)
        numCols=$(echo "$header" | awk -F, '{print NF}')

        header=$(echo "$csv" | head -n 1)
        dataRow=$(echo "$csv" | grep '^ERP_P_20,')

        > /tmp/popdata.csv

        for i in $(seq 4 "$numCols"); do
            year=$(echo "$header" | awk -F, -v c="$i" '{print $c}')
            pop=$(echo "$dataRow" | awk -F, -v c="$i" '{print $c}')

            if [ -n "$pop" ]; then
                echo "$year,$pop" >> /tmp/popdata.csv
            fi
        done

        python3 /root/plot.py
        cat /root/population.png        

    else
        # Decide: is the request coordinates, or a POI name?
        if [[ "$request" =~ ^-?[0-9.]+,-?[0-9.]+$ ]]; then
            # --- coordinate input: split into x and y directly ---
            x=$(echo "$request" | cut -d, -f1)
            y=$(echo "$request" | cut -d, -f2)
        else
            # --- name input: look it up to get coordinates ---
            lookup=$(curl -sf -G \
              --data-urlencode "where=poiname='$request'" \
              --data-urlencode "outFields=*" \
              --data-urlencode "returnGeometry=true" \
              --data-urlencode "f=json" \
              "https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_POI/MapServer/0/query")
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "POI API Error"
                exit 1
            fi
            x=$(echo "$lookup" | jq -r '.features[0].geometry.x')
            y=$(echo "$lookup" | jq -r '.features[0].geometry.y')
        fi

        # --- guard: no valid coordinates found ---
        if [ "$x" = "null" ] || [ -z "$x" ]; then
            echo "API Returned Null"
        else
            # --- find all POIs within 5 km ---
            neighbours=$(curl -sf -G \
              --data-urlencode "geometry=$x,$y" \
              --data-urlencode "geometryType=esriGeometryPoint" \
              --data-urlencode "inSR=4283" \
              --data-urlencode "distance=5000" \
              --data-urlencode "units=esriSRUnit_Meter" \
              --data-urlencode "spatialRel=esriSpatialRelIntersects" \
              --data-urlencode "outFields=poiname" \
              --data-urlencode "returnGeometry=false" \
              --data-urlencode "f=json" \
              "https://maps.six.nsw.gov.au/arcgis/rest/services/public/NSW_POI/MapServer/0/query")
            status=$?
            if [ "$status" -ne 0 ]; then
                echo "POI API Error"
                exit 1
            fi
            echo "$neighbours" | jq '[.features[].attributes.poiname | select(. != null)]'
        fi
    fi
    rm -f "$lockfile"
    exit 0
fi

ipAddr=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')
SCRIPT_PATH=$(readlink -f "$0")

# Start ncat listening in the background (allowed per Ed #622 to use 1234 here)
ncat -lk -p 1234 --sh-exec "bash $SCRIPT_PATH handle" &

# Give ncat a moment to start listening, then read the port back from ss -ltn
sleep 1
port=$(ss -ltn | grep LISTEN | awk '{print $4}' | sed 's/.*://' | head -n 1)

echo "The server is running at $ipAddr, port=$port"

# Keep the script alive so the background ncat keeps serving
wait