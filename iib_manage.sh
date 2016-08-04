#!/bin/bash
# © Copyright IBM Corporation 2015.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html

set -e

NODE_NAME=${NODENAME-IIBV10NODE}
WEB_ADMIN_PORT=${WEBADMINPORT-9080}

stop()
{
	echo "----------------------------------------"
	echo "Stopping node $NODE_NAME..."
	sudo su - iibuser -c "mqsistop $NODE_NAME"
}

start()
{

	HOST_EXISTS=`grep $HOSTNAME /etc/hosts ; echo $? `
	if [ ${HOST_EXISTS} -ne 0 ]; then
	    echo cat /etc/hosts
	    cp /etc/hosts /tmp/hosts
	    echo "Adding hostname $HOSTNAME to /etc/hosts..."
	    sed "$ a 127.0.0.1 $HOSTNAME " -i /tmp/hosts
	    cp /tmp/hosts /etc/hosts
	    rm /tmp/hosts
	    cat /etc/hosts
	fi

	echo "----------------------------------------"
	sudo su - iibuser /opt/ibm/iib-10.0.0.0/iib version
	echo "----------------------------------------"

	NODE_EXISTS=`sudo su - iibuser -c mqsilist | grep $NODE_NAME > /dev/null ; echo $? `

	echo "Starting rsyslogd..."
	/usr/sbin/rsyslogd

	if [ ${NODE_EXISTS} -ne 0 ]; then
	    echo "----------------------------------------"
	    echo "Node $NODE_NAME does not exist..."
	    echo "Creating node $NODE_NAME"
	    sudo su - iibuser -c "mqsicreatebroker $NODE_NAME"
	    echo "Starting ${NODE_NAME}..."
	    sudo su - iibuser -c "mqsistart $NODE_NAME"
	    echo "Changing webdmin port to $WEB_ADMIN_PORT"
	    sudo su - iibuser -c "mqsichangeproperties $NODE_NAME -b webadmin -o HTTPConnector -n port -v ${WEB_ADMIN_PORT}"
	else
	    sudo su - iibuser -c "mqsistart $NODE_NAME"
	fi
	echo "----------------------------------------"
	echo "Listing node $NODE_NAME details..."
	sudo su - iibuser -c "mqsilist"
	echo "----------------------------------------"

}

monitor()
{
	echo "----------------------------------------"
	echo "Running - stop container to exit"
	# Loop forever by default - container must be stopped manually.
	# Here is where you can add in conditions controlling when your container will exit - e.g. check for existence of specific processes stopping or errors beiing reported
	while true; do
		sleep 1
	done
}

iib-license-check.sh
start
trap stop SIGTERM SIGINT
monitor
