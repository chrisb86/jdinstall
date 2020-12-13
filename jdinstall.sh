#!/usr/bin/env sh

# jdinstall.sh
# Copyright 2020 Christian Baer
# http://git.debilux.org/chbaer/jdinstall

# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTI

BASEDIR="/usr/local/share/java/jdownloader"
RC_SCRIPT="/usr/local/etc/rc.d/jdownloader"
JD_DEPENDENCIES="openjdk8"
MKDIR="${BASEDIR} /usr/local/etc/rc.d /var/log/"

## Check dependencies
for pkg in ${JD_DEPENDENCIES}; do
	if ! pkg info ${pkg} > /dev/null; then
		echo ">>> Installing ${pkg}"
		pkg install -y ${pkg}
	fi
done

## Create user and directories
echo ">>> Creating user and directories"
pw user add jdownloader -c jdownloader -u 1001 -d /nonexistent -s /usr/bin/nologin
mkdir -p ${MKDIR}

## Download JDownloder

if [ ! -f "${BASEDIR}/JDownloader.jar" ]; then
	echo ">>> Downloading JDownloader"
	fetch http://installer.jdownloader.org/JDownloader.jar -o ${BASEDIR}
fi

## Install rc script
echo ">>> Installing rc script ${RC_SCRIPT}."
cat <<\EOF > ${RC_SCRIPT}
#!/bin/sh

# PROVIDE: jdownloader
# REQUIRE: LOGIN
# KEYWORD: shutdown

#
# Add the following line to /etc/rc.conf to enable 'jdownloader':
#
# jdownloader_enable="YES"
#
# Other configuration settings for jdownloader that can be set in /etc/rc.conf:
#
# jdownloader_user (str)
#   This is the user that jdownloader runs as
#   Set to jdownloader by default
#
# jdownloader_group (str)
#   This is the group that jdownloader runs as
#   Set to jdownloader by default
#
# jdownloader_chdir (str)
#   This is the directory that jdownloader chdirs into before starting
#   Set to /usr/local/share/java/jdownloader by default
#
# jdownloader_java_home (str)
#   The path to the base directory for the Java to use to run jdownloader
#   Defaults to /usr/local/openjdk8
#
# jdownloader_javaflags (str)
#   Flags passed to Java to run jdownloader
#   Set to "-Djava.awt.headless=true -Xmx1024M" by default
#

. /etc/rc.subr
name=jdownloader

rcvar=jdownloader_enable
load_rc_config ${name}

: ${jdownloader_enable:=NO}
: ${jdownloader_user:=jdownloader}
: ${jdownloader_group:=jdownloader}
: ${jdownloader_chdir=/usr/local/share/java/jdownloader}
: ${jdownloader_java_home=/usr/local/openjdk8}
: ${jdownloader_javaflags="-Djava.awt.headless=true -Xmx1024M"}

pidfile="${jdownloader_chdir}/JDownloader.pid"
procname=${jdownloader_java_home}/bin/java
command=/usr/sbin/daemon
command_args="-f ${jdownloader_java_home}/bin/java ${jdownloader_javaflags} -jar ${jdownloader_chdir}/JDownloader.jar"
start_precmd=start_precmd
stop_precmd=stop_precmd
stop_postcmd=stop_postcmd

export CLASSPATH=$(echo ${jdownloader_chdir}/lib/*.jar | tr ' ' ':')

start_precmd()
{
	if [ ! -e /var/log/${name} ] ; then
		install -d -o ${jdownloader_user} -g ${jdownloader_group} /var/log/${name};
	fi
}

stop_precmd()
{
	if [ -r ${pidfile} ]; then
		_jdownloaderPID=$(check_pidfile ${pidfile} ${procname})
		export _jdownloader_CHILDREN=$(pgrep -P ${_jdownloaderPID})
	fi
}

stop_postcmd()
{
	if ! [ -z ${_jdownloader_CHILDREN} ]; then
		echo "Cleaning up leftover child processes."
		kill $sig_stop ${_jdownloader_CHILDREN}
		wait_for_pids ${_jdownloader_CHILDREN}
	fi
}

run_rc_command "$1"

EOF

chmod u+x ${RC_SCRIPT}

## Set permissions
echo ">>> Setting permissions."
chown -R jdownloader:jdownloader ${MKDIR}

echo ">>> Enabling jdownloader service"
sysrc "jdownloader_enable=YES"

## Run JDownloader two times to install updates and configure my.jdownloder.org access
echo ">>> Starting JDownloader for first configuration"
/usr/local/bin/java -jar ${BASEDIR}/JDownloader.jar -norestart
/usr/local/bin/java -jar ${BASEDIR}/JDownloader.jar -norestart

service jdownloader start