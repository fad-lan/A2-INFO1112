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
    elif [ "$request" = "population" ]; then
        echo "DEBUG: population request"
    else
        echo "DEBUG: POI or unknown"
    fi
    echo "client IP was: $clientIP"

done

