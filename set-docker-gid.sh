﻿#!/bin/bash

DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
usermod -a -G $DOCKER_GID  jenkins
echo "added jenkins to $DOCKER_GID group (used by docker on underlying system)"
