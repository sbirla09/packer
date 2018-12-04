#!/bin/bash -x

set -e

export PATH="/usr/sbin:/sbin:/usr/local/bin:/usr/local/sbin:$PATH"
SUDO_CMD="sudo"
YUM_CMD="$SUDO_CMD yum"
AMZN_EXTRAS="$SUDO_CMD amazon-linux-extras"
PIP_CMD="$SUDO_CMD pip"
SVCTL_CMD="$SUDO_CMD systemctl"
ANSIBLE_VER="2.6.3"

# Clear yum cache so it downloads a fresh copy from the Internet and
# we can leverage that to check if EC2 instance has the Internet connection.
$YUM_CMD clean all
# Check the internet connection
echo "Checking if the instance has Interent connection"
timeout --foreground  --kill-after 1m 1m $YUM_CMD repolist > /dev/null 2>&1
if [ $? -eq 124 ] ; then
  echo "Command yum repolist timed out. Please check if the EC2 instance is connected to the Internet"
  exit 1
fi

echo "upgrading all software to the latest version"
$YUM_CMD update -y || YUM_FAILED=1
echo "installing other packages via yum"
$YUM_CMD install -y python-pip python-virtualenv yum-utils ntp ntpdate || YUM_FAILED=1
echo "installing extra packages via yum"
$AMZN_EXTRAS install -y epel || YUM_FAILED=1

if [[ YUM_FAILED == 1 ]]; then
  echo "ERROR: Failed to install one or more packages"
  exit 1
fi

echo "installing pip packages"
$PIP_CMD install ansible==$ANSIBLE_VER requests boto3 || PIP_FAILED=1

if [[ "$PIP_FAILED" == 1 ]] ; then
  echo "ERROR: Failed to install one or more pip packages"
  exit 1
fi

# enable dockerd/ntp services so they are up on the boot
$SVCTL_CMD enable ntpd rsyslog

# Clean up AMI before exit
$YUM_CMD clean all
$SUDO_CMD rm -rf /var/cache/yum/
exit 0
