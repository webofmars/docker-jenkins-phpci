Jenkins PHPCI docker image with aws / docker / rancher tools installed
================================================================================

Based on the work of iliyan-trifonov :
  https://github.com/iliyan-trifonov/docker-jenkins-ci-php

webofmars customizations
=========================

* upgraded to jenkins 2.0
* added docker commands : docker / docker-compose / docker-machine
* added rancher-compose (v0.7.3)
* added awscli
* added the following jenkins plugins :
  - octoperf
  - docker-commons
  - docker-build-step
  - aws-credentials
  - aws-java-sdk
  - ec2
  - envinject
* removed the default php template job
* secure installation by default. Default password is now 'changeit2016!'

Versions:
==========
  - v1.3.1
