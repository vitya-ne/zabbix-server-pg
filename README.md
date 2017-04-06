# zabbix-server-pg
Zabbix server docker image with PostgreSQL database support.

The main differences from the official image:
 - The container does not need access to the PostgreSQL server under the postgres account. (It is understood that all the necessary steps to create the zabbix database have already been done);
 - Server starts with a key --ipv6 = false;
 
Image are based on Alpine image.

## Start `zabbix-server-pg`

Start a Zabbix server container as follows:
```console
$ make run DB_HOST="X.X.X.X" DB_PORT="YYYY" PG_PASS="ZZZZZZZZ"
```
