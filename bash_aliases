sshtopi() {
	endpoint=$1
	daline=$(grep $endpoint ~/map-ports-service.txt | head -1 )
	echo -e "\u001b[7m$daline\u001b[0m"
	port=$(echo $daline | sed 's/,.*$//' )
	ssh -p $port pi@localhost
}

killconnection() {
  if [ -z "$1" ]; then
    ps -ef | grep -v  grep | grep connect\+  | awk '{print $2}' | sudo xargs kill -9
  else
    endpoint=$1
    sudo netstat -apn | grep ssh | grep $(grep $endpoint ~/map-ports-service.txt | head -1 | sed 's/,.*$//') | awk '{print $7}' | sed 's/\/.*$//' | sudo xargs kill -9
  fi
 }
    
