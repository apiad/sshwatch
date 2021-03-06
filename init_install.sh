#!/bin/bash
#---------------------------------EDIT HERE-----------------------------------------
name="sshwatch"
shot_desc="SSH config swapper."
desc="A daemon to swap the ~/.ssh/config file in correspondence with the network profile."

user="$(whoami)" #the user name that will run the script
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #get the bash script directory
script_path="$dir/$name"
#Uncomment this line to set the path of a configuration file
#script_config="$dir/config.json"

daemon_pwd="/usr/local/bin"
daemon_path="/usr/local/bin/$name"
daemon_config="/etc/$name"
daemon_opts="none"
#-----------------END OF EDIT UNLESS YOU KNOW WHAT YOU ARE DOING--------------------

if [[ $# -eq 1 && "$1" = "-u" ]]; then
	sudo service "$name" stop
	sudo rm "$daemon_path"
	sudo rm -rf "$daemon_config"
	sudo rm "/etc/init.d/$name"
	sudo update-rc.d "$name" remove
	exit
fi

service="#!/bin/sh
### BEGIN INIT INFO
# Provides:          $name
# Required-Start:    \$local_fs \$remote_fs \$network
# Required-Stop:     \$local_fs \$remote_fs \$network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: $shot_desc
# Description:       $desc
### END INIT INFO


# Documentation available at
# http://refspecs.linuxfoundation.org/LSB_3.1.0/LSB-Core-generic/LSB-Core-generic/iniscrptfunc.html
# Debian provides some extra functions though
. /lib/lsb/init-functions


DAEMON_NAME=\"$name\"
DAEMON_USER=\"$user\"
DAEMON_PATH=\"$daemon_path\"
DAEMON_OPTS=\"$daemon_opts\"
DAEMON_PWD=\"$daemon_pwd\"

DAEMON_PID=\"/var/run/\${DAEMON_NAME}.pid\"
DAEMON_LOG=\"/var/log/\${DAEMON_NAME}.log\"
DAEMON_DESC=\$(get_lsb_header_val \$0 \"Short-Description\")
DAEMON_NICE=0

[ -r \"/etc/default/\${DAEMON_NAME}\" ] && . \"/etc/default/\${DAEMON_NAME}\"

do_start() {
  local result

	pidofproc -p \"\${DAEMON_PID}\" \"\${DAEMON_PATH}\" > /dev/null
	if [ \$? -eq 0 ]; then
		log_warning_msg \"\${DAEMON_NAME} is already started\"
		result=0
	else
		log_daemon_msg \"Starting \${DAEMON_DESC}\" \"\${DAEMON_NAME}\"
		touch \"\${DAEMON_LOG}\"
		chown \$DAEMON_USER \"\${DAEMON_LOG}\"
		chmod u+rw \"\${DAEMON_LOG}\"
		if [ -z \"\${DAEMON_USER}\" ]; then
			start-stop-daemon --start --quiet --oknodo --background \\
				--nicelevel \$DAEMON_NICE \\
				--chdir \"\${DAEMON_PWD}\" \\
				--pidfile \"\${DAEMON_PID}\" --make-pidfile \\
				--startas /bin/bash -- -c \"exec \${DAEMON_PATH} \${DAEMON_OPTS} >> \${DAEMON_LOG} 2>&1\"
			result=\$?
		else
			start-stop-daemon --start --quiet --oknodo --background \\
				--nicelevel \$DAEMON_NICE \\
				--chdir \"\${DAEMON_PWD}\" \\
				--pidfile \"\${DAEMON_PID}\" --make-pidfile \\
				--chuid \"\${DAEMON_USER}\" \\
				--startas /bin/bash -- -c \"exec \${DAEMON_PATH} \${DAEMON_OPTS} >> \${DAEMON_LOG} 2>&1\"
			result=\$?
		fi
		log_end_msg \$result
	fi
	return \$result
}

do_stop() {
	local result

	pidofproc -p \"\${DAEMON_PID}\" \"\${DAEMON_PATH}\" > /dev/null
	if [ \$? -ne 0 ]; then
		log_warning_msg \"\${DAEMON_NAME} is not started\"
		result=0
	else
		log_daemon_msg \"Stopping \${DAEMON_DESC}\" \"\${DAEMON_NAME}\"
		killproc -p \"\${DAEMON_PID}\" \"\${DAEMON_PATH}\"
		result=\$?
		log_end_msg \$result
		rm \"\${DAEMON_PID}\"
	fi
	return \$result
}

do_restart() {
	local result
	do_stop
	result=\$?
	if [ \$result = 0 ]; then
		do_start
		result=\$?
	fi
	return \$result
}

do_status() {
	local result
	status_of_proc -p \"\${DAEMON_PID}\" \"\${DAEMON_PATH}\" \"\${DAEMON_NAME}\"
	result=\$?
	return \$result
}

do_usage() {
	echo \$\"Usage: \$0 {start | stop | restart | status}\"
	exit 1
}

case \"\$1\" in
start)   do_start;   exit \$? ;;
stop)    do_stop;    exit \$? ;;
restart) do_restart; exit \$? ;;
status)  do_status;  exit \$? ;;
*)       do_usage;   exit  1 ;;
esac
"

printf "$service" > "/tmp/$name"
#copy the executable to local/bin
sudo cp "$script_path" "$daemon_path"
sudo chmod +x "$daemon_path"

#copy the configuration if it is declared
sudo mkdir -p "$daemon_config"
if [[ -n "${script_config}" ]]; then
	sudo cp "$script_config" "$daemon_config/${name}.config"
fi

#install the init script
sudo mv "/tmp/$name" "/etc/init.d/$name"
sudo chmod +x "/etc/init.d/$name"
sudo service "$name" start
sudo update-rc.d "$name" defaults

