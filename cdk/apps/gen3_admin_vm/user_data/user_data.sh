#!/bin/bash

echo "Running custom user data...."
# Vars:
EXT_DEV_NAME=${__EXT_DEV_NAME__}
EXT_DEV_MOUNT=${__EXT_DEV_MOUNT__}

echo "Configuring instance with ext mount: $EXT_DEV_NAME on $EXT_DEV_MOUNT"

# Set time/logs to melbourne time
echo "Set time to Melbourne time"
ln -sf /usr/share/zoneinfo/Australia/Melbourne /etc/localtime

if [ ! -d "$EXT_DEV_MOUNT" ]; then
  # Partition external volume
  mkfs -t ext4 "$EXT_DEV_NAME"
  mkdir -p "$EXT_DEV_MOUNT"
  echo "$EXT_DEV_NAME       $EXT_DEV_MOUNT   ext4    rw,user,suid,dev,exec,auto,async 0       2" >> /etc/fstab
  mount -a

  # Create the gen3 user
  mkdir -p "$EXT_DEV_MOUNT/home"
  useradd gen3-user \
    --shell /bin/bash \
    --base-dir "$EXT_DEV_MOUNT/home" \
    --create-home
else
  echo "$EXT_DEV_MOUNT exists, skipping init process."
fi

# Give ssm-user an irresponsible level of sudo permission
echo "# User rules for gen3-user" > "/etc/sudoers.d/gen3-user"
echo "gen3-user ALL=(ALL) NOPASSWD:ALL" >> "/etc/sudoers.d/gen3-user"

echo "Custom user data done."
