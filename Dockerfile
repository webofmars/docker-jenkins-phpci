FROM ubuntu:14.04
MAINTAINER webofmars <contact@webofmars.com>

RUN echo "deb http://mirrors.us.kernel.org/ubuntu/ trusty main restricted universe multiverse" > /etc/apt/sources.list; \
	  echo "deb http://mirrors.us.kernel.org/ubuntu/ trusty-updates main restricted universe multiverse" >> /etc/apt/sources.list; \
	  echo "deb http://mirrors.us.kernel.org/ubuntu/ trusty-backports main restricted universe multiverse" >> /etc/apt/sources.list; \
	  echo "deb http://mirrors.us.kernel.org/ubuntu/ trusty-security main restricted universe multiverse" >> /etc/apt/sources.list

RUN export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
	  apt-get -qq install wget ssh

RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 14AA40EC0831756756D7F66C4F4EA0AAE5267A6C; \
	  echo "deb http://ppa.launchpad.net/ondrej/php5-5.6/ubuntu trusty main" >> /etc/apt/sources.list; \
	  echo "deb-src http://ppa.launchpad.net/ondrej/php5-5.6/ubuntu trusty main" >> /etc/apt/sources.list

RUN wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add - > /dev/null 2>&1; \
	  echo "deb http://pkg.jenkins-ci.org/debian binary/" > /etc/apt/sources.list.d/jenkins.list

RUN export DEBIAN_FRONTEND=noninteractive; \
	  apt-get update; \
	  apt-get -qq install --no-install-recommends php5 php5-cli php5-xsl php5-json php5-curl php5-sqlite php5-mysqlnd php5-xdebug php5-intl php5-mcrypt php-pear curl git ant jenkins docker.io python-pip; \
    pip install awscli

# get rid of the GID problem when running docker inside docker
ADD set-docker-gid.sh /usr/local/bin/set-docker-gid
RUN chmod a+x /usr/local/bin/set-docker-gid

ADD docker-compose-run.sh /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

ADD install-docker-machine /opt/tools/
RUN bash /opt/tools/install-docker-machine

ADD install-rancher-compose /opt/tools/
RUN bash /opt/tools/install-rancher-compose

# Jenkins config
ADD config.xml.1 /var/lib/jenkins/config.xml
ADD config-admin.xml /var/lib/jenkins/users/admin/config.xml

RUN service jenkins start; \
	  while ! echo exit | nc -z -w 3 localhost 8080; do sleep 3; done; \
	  while curl -s http://localhost:8080 | grep "Please wait" >/dev/null; do echo "Waiting for Jenkins to start.." && sleep 3; done; \
	  echo "Jenkins started"; \
    cd /var/lib/jenkins && wget http://localhost:8080/jnlpJars/jenkins-cli.jar; \
    java -jar jenkins-cli.jar -s http://localhost:8080 install-plugin ace-editor ant antisamy-markup-formatter branch-api build-timeout cloudbees-folder credentials-binding credentials durable-task email-ext external-monitor-job git-client git-server git github-api github-branch-source github-organization-folder github gradle handlebars icon-shim javadoc jquery-detached junit ldap mailer mapdb-api matrix-auth matrix-project momentjs pam-auth pipeline-build-step pipeline-input-step pipeline-rest-api pipeline-stage-step pipeline-stage-view plain-credentials scm-api script-security ssh-credentials ssh-slaves structs subversion timestamper token-macro windows-slaves workflow-aggregator workflow-api workflow-basic-steps workflow-cps-global-lib workflow-cps workflow-durable-task-step workflow-job workflow-multibranch workflow-scm-step workflow-step-api workflow-support ws-cleanup; \
    java -jar jenkins-cli.jar -s http://localhost:8080 install-plugin checkstyle cloverphp crap4j dry htmlpublisher jdepend plot pmd violations warnings xunit git ansicolor; \
    java -jar jenkins-cli.jar -s http://localhost:8080 install-plugin octoperf docker-commons docker-build-step; \
    java -jar jenkins-cli.jar -s http://localhost:8080 install-plugin envinject aws-credentials aws-java-sdk ec2; \
    java -jar jenkins-cli.jar -s http://localhost:8080 safe-restart

#RUN rm /var/lib/jenkins/secrets/initialAdminPassword
ADD config.xml.2 /var/lib/jenkins/config.xml

RUN sed -i 's|disable_functions.*=|;disable_functions=|' /etc/php5/cli/php.ini; \
	  echo "xdebug.max_nesting_level = 500" >> /etc/php5/mods-available/xdebug.ini

RUN mkdir -p /home/jenkins/composerbin && chown -R jenkins:jenkins /home/jenkins; \
	  sudo -H -u jenkins bash -c ' \
		  curl -sS https://getcomposer.org/installer | php -- --install-dir=/home/jenkins/composerbin --filename=composer;'; \
	  ln -s /home/jenkins/composerbin/composer /usr/local/bin/; \
	  sudo -H -u jenkins bash -c ' \
  		export COMPOSER_BIN_DIR=/home/jenkins/composerbin; \
  		export COMPOSER_HOME=/home/jenkins; \
  		composer global require "phpunit/phpunit=*" --prefer-source --no-interaction; \
  		composer global require "squizlabs/php_codesniffer=*" --prefer-source --no-interaction; \
  		composer global require "phploc/phploc=*" --prefer-source --no-interaction; \
  		composer global require "pdepend/pdepend=*" --prefer-source --no-interaction; \
  		composer global require "phpmd/phpmd=*" --prefer-source --no-interaction; \
  		composer global require "sebastian/phpcpd=*" --prefer-source --no-interaction; \
  		composer global require "theseer/phpdox=*" --prefer-source --no-interaction; '; \
  	ln -s /home/jenkins/composerbin/pdepend /usr/local/bin/; \
  	ln -s /home/jenkins/composerbin/phpcpd /usr/local/bin/; \
  	ln -s /home/jenkins/composerbin/phpcs /usr/local/bin/; \
  	ln -s /home/jenkins/composerbin/phpdox /usr/local/bin/; \
  	ln -s /home/jenkins/composerbin/phploc /usr/local/bin/; \
  	ln -s /home/jenkins/composerbin/phpmd /usr/local/bin/; \
  	ln -s /home/jenkins/composerbin/phpunit /usr/local/bin/

RUN echo 'if [ -z "$TIME_ZONE" ]; then echo "No TIME_ZONE env set!" && exit 1; fi' > /set_timezone.sh; \
  	echo "sed -i 's|;date.timezone.*=.*|date.timezone='\$TIME_ZONE'|' /etc/php5/cli/php.ini;" >> /set_timezone.sh; \
  	echo "echo \$TIME_ZONE > /etc/timezone;" >> /set_timezone.sh; \
  	echo "export DEBCONF_NONINTERACTIVE_SEEN=true DEBIAN_FRONTEND=noninteractive;" >> /set_timezone.sh; \
  	echo "dpkg-reconfigure tzdata" >> /set_timezone.sh; \
  	echo "echo time zone set to: \$TIME_ZONE"  >> /set_timezone.sh

RUN echo 'if [ -n "$TIME_ZONE" ]; then sh /set_timezone.sh; fi;' > /run_all.sh; \
    echo '/usr/local/bin/set-docker-gid' >> /run_all.sh; \
    echo 'chown -R jenkins:jenkins /var/lib/jenkins' >> /run_all.sh; \
  	echo "service jenkins start" >> /run_all.sh; \
    echo "echo>/var/log/jenkins/jenkins.log" >> /run_all.sh; \
  	echo "tail -f /var/log/jenkins/jenkins.log;" >> /run_all.sh

RUN rm -rf /tmp/* && apt-get clean

EXPOSE 8080

CMD ["sh", "/run_all.sh"]