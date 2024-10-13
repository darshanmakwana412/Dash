#!/bin/bash

echo "Starting the web server..."
# python3 -m http.server --directory ./public 8080 &/
# SERVER_PID=$!

# Watch for changes and rebuild
inotifywait -m -r --exclude '/public/' -e close_write --format '%w%f' . | while read FILE
do
    echo "Change detected in $FILE"
    echo "Building ..."

    time source build.sh
done

# kill $SERVER_PID