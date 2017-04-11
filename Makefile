
DOCKER_IMAGE=megbeguk/zabbix-server-pg
DOCKER_CONTAINER=zabbix-server

# set param from cmd:
# make build DB_HOST="X.X.X.X" DB_PORT="YYYY" PG_PASS="ZZZZZZZZ"
#

list:
	docker ps -a
	docker images -a

build:
	docker build -t $(DOCKER_IMAGE) src/
	docker images -a | grep $(DOCKER_IMAGE)

bash:
	docker run --rm --name $(DOCKER_CONTAINER)_bash -it $(DOCKER_IMAGE) bash

shell:
	docker exec -i -t $(DOCKER_CONTAINER) bash

run:
	docker run -d -t -e DB_SERVER_HOST=$(DB_HOST) -e DB_SERVER_PORT=$(DB_PORT) -e POSTGRES_USER="zabbix" -e POSTGRES_PASSWORD=$(PG_PASS) -e POSTGRES_DB="zabbix" -e ZBX_ENABLE_SNMP_TRAPS="true" -p 10051:10051 --volumes-from zabbix-snmptraps --link zabbix-agent:zabbix-agent --name $(DOCKER_CONTAINER) $(DOCKER_IMAGE)

log:
	docker logs $(DOCKER_CONTAINER)

rm:
	docker stop $(DOCKER_CONTAINER)
	docker rm $(DOCKER_CONTAINER)

rmi:
	docker rmi $(DOCKER_IMAGE)
ifeq ("$(VOL_DANG)", "")
	@echo "dangling volumes: none"
else
	@echo "remove dangling volumes:"
	docker volume rm $(VOL_DANG)
endif
ifeq ("$(IMG_DANG)","")
	@echo "dangling images: none"
else
	@echo "remove dangling images:"
	docker rmi $(IMG_DANG)
endif
