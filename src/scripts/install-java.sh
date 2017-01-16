#!/bin/bash

# License: https://github.com/elastic/azure-marketplace/blob/master/LICENSE.txt
#
# Martijn Laarman, Greg Marzouka, Russ Cam (Elastic)
# Contributors
#

#########################
# Install Java with brute force retries
# Installing java is from apt-get fails often on sha mismatches and other errors
# e.g seemingly downloading ok but installing fails.
#########################

log()
{
    echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1"
    echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1" >> /var/log/arm-install.log
}
# Install Oracle Java
install_java()
{
    log "[install_java] Adding apt repository for java 8"
    (add-apt-repository -y ppa:webupd8team/java || (sleep 15; add-apt-repository -y ppa:webupd8team/java))
    log "[install_java] updating apt-get"

    (apt-get -y update || (sleep 15; apt-get -y update)) > /dev/null
    log "[install_java] updated apt-get"
    echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
    log "[install_java] Installing Java"
    (apt-get -yq install oracle-java8-installer || (sleep 15; apt-get -yq install oracle-java8-installer))
    command -v java >/dev/null 2>&1 || { sleep 15; sudo rm /var/cache/oracle-jdk8-installer/jdk-*; sudo apt-get install -f; }

    #if the previus did not install correctly we go nuclear, otherwise this loop will early exit
    for i in $(seq 30); do
      if $(command -v java >/dev/null 2>&1); then
        log "[install_java] Installed java!"
        return
      else
        sleep 5
        sudo rm /var/cache/oracle-jdk8-installer/jdk-*;
        sudo rm -f /var/lib/dpkg/info/oracle-java8-installer*
        sudo rm /etc/apt/sources.list.d/*java*
        sudo apt-get -yq purge oracle-java8-installer*
        sudo apt-get -yq autoremove
        sudo apt-get -yq clean
        (add-apt-repository -y ppa:webupd8team/java || (sleep 15; add-apt-repository -y ppa:webupd8team/java))
        sudo apt-get -yq update
        sudo apt-get -yq install --reinstall oracle-java8-installer
        log "[install_java] Seeing if java is Installed after nuclear retry ${i}/30"
      fi
    done
    command -v java >/dev/null 2>&1 || { log "Java did not get installed properly even after a retry and a forced installation" >&2; exit 50; }
}
