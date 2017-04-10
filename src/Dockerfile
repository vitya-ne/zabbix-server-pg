FROM zabbix/zabbix-web-nginx-pgsql:alpine-3.2.4

ARG VER=3.2.4

ENV TERM=xterm
ENV ZBX_VERSION=${VER} ZBX_SOURCES=svn://svn.zabbix.com/tags/${VER}/ DB_TYPE=postgresql
ENV MIBDIRS=/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL

EXPOSE 10051/TCP 162/UDP

WORKDIR /var/lib/zabbix

VOLUME ["/usr/lib/zabbix/alertscripts", "/usr/lib/zabbix/externalscripts", "/var/lib/zabbix/enc", "/var/lib/zabbix/modules", "/var/lib/zabbix/ssh_keys"]
VOLUME ["/var/lib/zabbix/ssl/certs", "/var/lib/zabbix/ssl/keys", "/var/lib/zabbix/ssl/ssl_ca", "/var/lib/zabbix/snmptraps", "/var/lib/zabbix/mibs"]

COPY files /

ENTRYPOINT ["/bin/bash"]

CMD ["/run_zabbix_component.sh"]
