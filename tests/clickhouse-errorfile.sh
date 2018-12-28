#!/bin/bash
# add 2018-12-07 by Pascal Withopf, released under ASL 2.0
. ${srcdir:=.}/diag.sh init
generate_conf
add_conf '
module(load="../plugins/imtcp/.libs/imtcp")
module(load="../plugins/omclickhouse/.libs/omclickhouse")
input(type="imtcp" port="'$TCPFLOOD_PORT'")

template(name="outfmt" option.stdsql="on" type="string" string="INSERT INTO rsyslog.errorfile (id, severity, facility, timestamp, ipaddress, tag, message) VALUES (%msg:F,58:2%, %syslogseverity%, %syslogfacility%, '
add_conf "'%timereported:::date-unixtimestamp%', '%fromhost-ip%', '%syslogtag%', '%msg%')"
add_conf '")


:syslogtag, contains, "tag" action(type="omclickhouse" server="localhost" port="8443"
					user="default" pwd="" template="outfmt"
					bulkmode="off" errorfile="'$RSYSLOG_OUT_LOG'")
'

clickhouse-client --query="CREATE TABLE IF NOT EXISTS rsyslog.errorfile ( id Int32, severity Int8, facility Int8, timestamp DateTime, ipaddress String, tag String, message String ) ENGINE = MergeTree() PARTITION BY severity Order By id"

startup
tcpflood -m1 -M "\"<129>Mar 10 01:00:00 172.20.245.8 tag: msgnum:NoInteger\""
shutdown_when_empty
wait_shutdown

export EXPECTED="{ \"request\": { \"url\": \"http:\\/\\/localhost:8123\\/\", \"postdata\": \"INSERT INTO rsyslog.errorfile (id, severity, facility, timestamp, ipaddress, tag, message) VALUES (NoInteger, 1, 16, '1520643600', '127.0.0.1', 'tag:', ' msgnum:NoInteger')\" }, \"reply\": \"Code: 47, e.displayText() = DB::Exception: Unknown identifier: NoInteger, e.what() = DB::Exception\\n\" }"
cmp_exact $RSYSLOG_OUT_LOG

clickhouse-client --query="DROP TABLE rsyslog.errorfile"
exit_test
