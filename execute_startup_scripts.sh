#!/bin/bash

# Execute mq setup script
mq.sh &
# Execute iib setup script
iib_manage.sh

wait
echo "Scripts executed successfully!"
