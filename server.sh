#!/bin/bash

# Extract the server's own IP address (no hardcoding)
ipAddr=$(ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{print $1}')

# Extract the listening port via ss (no hardcoding of the displayed value)
port=$(ss -ltn | grep LISTEN | awk '{print $4}' | cut -d: -f2)

echo "The server is running at $ipAddr, port=$port"

# Infinite loop — serve forever
while true
do
    # Listen for one connection, capture what the client sends
    request=$(nc -l -v 1234 2>/tmp/ncinfo)
    clientIP=$(grep "Connection received" /tmp/ncinfo | awk '{print $4}')

    if [ "$request" = "assignment" ]; then
        echo "DEBUG: assignment request"
        html=$(curl -s "https://www.sydney.edu.au/units/INFO1112/2026-S2C-ND-CC")
        section=$(echo "$html" | grep -A 20 'Assignment 2')
        title=$(echo "$section" | grep -o 'Assignment 2' | head -n 1)
        points=$(echo "$section" | grep -o '[0-9]*%' | head -n 1 | tr -d '%')
        dueDate=$(echo "$section" | grep -o 'Due date</b>: [^<]*' | head -n 1 | sed 's/Due date<\/b>: //' | sed 's/ at//')
        topicFull=$(echo "$section" | grep -o 'Programming task - [^<]*' | head -n 1)
        topic=$(echo "$topicFull" | awk '{print $4}')
        echo "$topic"
        echo "$title"
        echo "$points"
        echo "$dueDate"
    elif [ "$request" = "population" ]; then
        echo "DEBUG: population request"
    else
        echo "DEBUG: POI or unknown"
    fi
    echo "client IP was: $clientIP"

done

