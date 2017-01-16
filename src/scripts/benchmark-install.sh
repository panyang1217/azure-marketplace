#!/bin/bash

# License: https://github.com/elastic/azure-marketplace/blob/master/LICENSE.txt
#
# Trent Swanson (Full Scale 180 Inc)
# Martijn Laarman, Greg Marzouka, Russ Cam (Elastic)
# Contributors
#
START_TIME=$SECONDS
# Custom logging with time so we can easily relate running times, also log to separate file so order is guaranteed.
# The Script extension output the stdout/err buffer in intervals with duplicates.
log()
{
    echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1"
    echo \[$(date +%d%m%Y-%H:%M:%S)\] "$1" >> /var/log/arm-install.log
}

#########################
# HELP
#########################

help()
{
    echo "This script installs a dedicated node in the topoplogy we can use to benchmark the cluster"
    echo "Parameters:"
    echo "-v elasticsearch version 1.5.0"
    echo "-p hostname prefix of nodes for unicast discovery"

    echo "-Z <number of nodes> hint to the install script how many data nodes we are provisioning"

    echo "-A admin password"

    echo "-l install plugins"

    echo "-j install azure cloud plugin for snapshot and restore"
    echo "-a set the default storage account for azure cloud plugin"
    echo "-k set the key for the default storage account for azure cloud plugin"

    echo "-h view this help content"
}

log "Begin execution of Elasticsearch script extension on ${HOSTNAME}"

export DEBIAN_FRONTEND=noninteractive

#########################
# Preconditions
#########################

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

#########################
# Parameter handling
#########################

NAMESPACE_PREFIX=""
ES_VERSION="2.0.0"
INSTALL_PLUGINS=0

DATANODE_COUNT=0
DATANODES="[data-0:9200]"

MINIMUM_MASTER_NODES=3
USER_ADMIN_PWD="changeME"

#Loop through options passed
while getopts :n:v:A:R:K:S:Z:p:a:k:L:xyzldjh optname; do
  log "Option $optname set"
  case $optname in
    v) #elasticsearch version number
      ES_VERSION=${OPTARG}
      ;;
    A) #shield admin pwd
      USER_ADMIN_PWD=${OPTARG}
      ;;
    Z) #number of data nodes hints (used to calculate minimum master nodes)
      DATANODE_COUNT=${OPTARG}
      ;;
    l) #install plugins
      INSTALL_PLUGINS=1
      ;;
    p) #namespace prefix for nodes
      NAMESPACE_PREFIX="${OPTARG}"
      ;;
    h) #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      log \\n"Option -${BOLD}$OPTARG${NORM} ignored."
      ;;
  esac
done

#########################
# Parameter state changes
#########################

DATANODES='['
for i in $(seq 0 $((DATANODE_COUNT-1))); do
    DATANODES="$DATANODES\"${NAMESPACE_PREFIX}data-$i:9300\","
done
DATANODES="${DATANODES%?}]"

log "Benchmarking against Elasticsearch $ES_VERSION "
log "Seeding benchmark to run against $DATANODES"
log "Cluster install plugins is set to $INSTALL_PLUGINS"

#########################
# Installation steps as functions
#########################

# Install Oracle Java
install_java()
{
    bash install-java.sh
}

# Format data disks (Find data disks then partition, format, and mount them as seperate drives)
format_data_disks()
{
    log "[format_data_disks] starting to RAID0 the attached disks"
    # using the -s paramater causing disks under /datadisks/* to be raid0'ed
    bash vm-disk-utils-0.1.sh -s
    log "[format_data_disks] finished RAID0'ing the attached disks"
}

#########################
# Installation sequence
#########################

format_data_disks

install_java

log "Update apt-get"
sudo apt-get -yq update

log "Install gcc"
sudo apt-get -yq install gcc
log "Install git"
sudo apt-get -yq install git
log "Install python3-dev"
sudo apt-get -yq install python3-dev
log "Install python3-pip"
sudo apt-get -yq install python3-pip
log "Install esrally"
sudo pip3 install esrally

log "Point esrally to use attached disks for its benchmark data"
sed -i 's/^root\.dir =.*$/root.dir = \/datadisks\/disk1\/benchmarks/g' ~/.rally/rally.ini

ELAPSED_TIME=$(($SECONDS - $START_TIME))
PRETTY=$(printf '%dh:%dm:%ds\n' $(($ELAPSED_TIME/3600)) $(($ELAPSED_TIME%3600/60)) $(($ELAPSED_TIME%60)))

log "End execution of benchmark install on ${HOSTNAME} in ${PRETTY}"
exit 0
