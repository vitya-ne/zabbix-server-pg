
DOCKER_IMAGE=megbeguk/zabbix-server-pg
DOCKER_CONTAINER=zabbix-server
VOL_DANG=$(docker volume ls -qf dangling=true)
IMG_DANG=$(docker images -f "dangling=true" -q)

# set param from cmd:
# make build DB_HOST="X.X.X.X" DB_PORT="YYYY" PG_PASS="ZZZZZZZZ"
#

list:
	docker ps -a
	docker images -a

build:
	docker build -t $(DOCKER_IMAGE) src/
	docker images -a | grep $(DOCKER_IMAGE)



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
