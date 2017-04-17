FROM zabbix/zabbix-server-pgsql:alpine-3.2-latest

EXPOSE 10051/TCP 162/UDP

WORKDIR /var/lib/zabbix

VOLUME ["/usr/lib/zabbix/alertscripts", "/usr/lib/zabbix/externalscripts"]
VOLUME [/var/lib/zabbix/ssl/ssl_ca", "/var/lib/zabbix/snmptraps", "/var/lib/zabbix/mibs"]

COPY files /

ENTRYPOINT ["/bin/bash"]

CMD ["/run_zabbix_component.sh"]
