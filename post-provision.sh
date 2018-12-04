#!/bin/bash -vx
#
export PATH="$PATH:."
# TODO provide a commandline option to change this
RETENTION_DAYS=7
MANIFEST_OUTPUT="manifest-${PACKER_RUN_UUID}.json"
LATEST_AMI=$(cat $MANIFEST_OUTPUT | jq --raw-output '.builds[0].artifact_id' | awk -F':' '{print $2}')
ME=$(basename $0)
# MacOS or Linux
OSNAME=$(uname)
if [[ "$OSNAME" == "Darwin" ]] ; then
  # On MacOS. Use date format used by mac
  DATE_CMD="date -jnu -f %Y-%m-%dT%H:%M:%S "
else
  DATE_CMD="date --date="
fi

# Ensure that the latest AMI is tagged green
aws ec2 create-tags --resources $LATEST_AMI  --tags Key=IsGreen,Value=true

# get all the old AMIs except the lastest one
OLD_AMIS=$(aws ec2 describe-images --filters "Name=tag:Name,Values=ypami-amazonlinux2" --output text --query 'Images[*].[ImageId,CreationDate,BlockDeviceMappings[0].Ebs.SnapshotId]' --output text | grep -iv $LATEST_AMI)

# delete IsGreen tags from the old AMIs
aws ec2 delete-tags --resources $(echo $OLD_AMIS | awk '{print $1}' | tr '\n' ' ') --tags Key=IsGreen

epoch_now=$(date '+%s')
secs_in_a_week=$(( 3600 * 24 * $RETENTION_DAYS ))
while read -r ami_date_snap
do
  ami=$(echo $ami_date_snap | awk '{print $1}')
  datestamp=$(echo $ami_date_snap | awk '{print $2}')
  snapshot=$(echo $ami_date_snap | awk '{print $3}')
  epoch_ami=$(${DATE_CMD}${datestamp}  '+%s' 2> /dev/null)
  ami_age=$((epoch_now - epoch_ami))
  if [[ "$ami_age" -gt "$secs_in_a_week" ]] ; then
    # more than a week old. de-register the ami.
    DEREG_CMD="aws ec2 deregister-image --image-id $ami"
    echo "deregitering AMI: $ami"
    echo $DEREG_CMD
    $DEREG_CMD
    DEL_SNAP_CMD="aws ec2 delete-snapshot --snapshot-id $snapshot"
    echo "deleting snapshot: $snapshot"
    echo $DEL_SNAP_CMD
    $DEL_SNAP_CMD
  fi
done <<< "$OLD_AMIS"
