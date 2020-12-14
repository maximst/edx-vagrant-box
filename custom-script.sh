#!/usr/bin/env bash

set -eux

# Sample custom configuration script - add your own commands here
# to add some additional commands for your environment
#
# For example:
# yum install -y curl wget git tmux firefox xvfb

cd /var/tmp/

export OPENEDX_RELEASE=open-release/juniper.3


wget https://raw.githubusercontent.com/edx/configuration/$OPENEDX_RELEASE/util/install/ansible-bootstrap.sh -O - | sudo -E bash

##
## Set ppa repository source for gcc/g++ 4.8 in order to install insights properly
##
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test

##
## Update and Upgrade apt packages
##
sudo apt-get update -y
sudo apt-get upgrade -y

##
## Install system pre-requisites
##
sudo apt-get install -y build-essential software-properties-common curl git-core libxml2-dev libxslt1-dev python3-pip libmysqlclient-dev python3-apt python3-dev libxmlsec1-dev libfreetype6-dev swig gcc g++ python3-mysqldb mysql-server
# ansible-bootstrap installs yaml that pip 19 can't uninstall.
sudo apt-get remove -y python-yaml

sudo -H pip install --upgrade pip==20.0.2
sudo -H pip install --upgrade setuptools==44.1.0
sudo -H pip install --upgrade virtualenv==16.7.10

##
## Overridable version variables in the playbooks. Each can be overridden
## individually, or with $OPENEDX_RELEASE.
##
VERSION_VARS=(
    edx_platform_version
    certs_version
    forum_version
    onfiguration_version
    demo_version
    EDX_PLATFORM_VERSION
    CERTS_VERSION
    FORUM_VERSION
    XQUEUE_VERSION
    CONFIGURATION_VERSION
    DEMO_VERSION
    INSIGHTS_VERSION
    ANALYTICS_API_VERSION
    ECOMMERCE_VERSION
    ECOMMERCE_WORKER_VERSION
    DISCOVERY_VERSION
    THEMES_VERSION
    ACCOUNT_MFE_VERSION
    GRADEBOOK_MFE_VERSION
    PROFILE_MFE_VERSION
)
EXTRA_VARS=''
for var in ${VERSION_VARS[@]}; do
    # Each variable can be overridden by a similarly-named environment variable,
    # or OPENEDX_RELEASE, if provided.
    ENV_VAR=$(echo $var | tr '[:lower:]' '[:upper:]')
    eval override=\${$ENV_VAR-\$OPENEDX_RELEASE}
    if [ -n "$override" ]; then
        EXTRA_VARS="-e $var=$override $EXTRA_VARS"
    fi
done

#EDXAPP_EDXAPP_SECRET_KEY
#EXTRA_VARS="-e@$(pwd)/config.yml $EXTRA_VARS"

CONFIGURATION_VERSION=${CONFIGURATION_VERSION-$OPENEDX_RELEASE}

##
## Clone the configuration repository and run Ansible
##
cd /var/tmp
git clone https://github.com/edx/configuration
cd configuration
git checkout $CONFIGURATION_VERSION
git pull

##
## Install the ansible requirements
##
cd /var/tmp/configuration
sudo -H pip install -r requirements.txt

sed '/- analytics_pipeline/d' playbooks/vagrant-analytics.yml
sed -i "13 a \    SDISCOVERY_URL_ROOT: 'http://localhost:{{ DISCOVERY_NGINX_PORT }}'" playbooks/vagrant-analytics.yml
echo "    - discovery" >> playbooks/vagrant-analytics.yml

##
## Run the $ playbook in the configuration/playbooks directory
##
cd /var/tmp/configuration/playbooks && sudo -E ansible-playbook -c local ./vagrant-analytics.yml -i "localhost," $EXTRA_VARS "$@"
