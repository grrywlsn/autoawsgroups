#!/bin/bash
#
#  Updates security groups with IP addresses within the AWS account
#  https://github.com/grrywlsn/autoawsgroups
#  MetaBroadcast.com


IFS="
"

# generate a list of all ative instances 
declare -A CURRENT_INSTANCES
ALL_INSTANCES=`ec2-describe-instances --filter="instance-state-name=running"`

 for INSTANCE in ${ALL_INSTANCES[@]}
  do
  INSTANCE_ID=""
  if [[ $INSTANCE == *RESERVATION* ]]
    then
      INSTANCE_SG=`echo $INSTANCE | awk '{print $4}'`
    fi

  if [[ $INSTANCE == *INSTANCE* ]]
    then  
    if [[ ! `echo $INSTANCE | awk '{print $14}'` == *10.* ]]
        then
        INSTANCE_ID=`echo $INSTANCE | awk '{print $2}'`
        INSTANCE_IP=`echo $INSTANCE | awk '{print $14}'`
        else
          if [[ ! `echo $INSTANCE | awk '{print $13}'` == *monitoring-disabled* ]]
          then
          INSTANCE_IP=`echo $INSTANCE | awk '{print $13}'`
          fi
        fi
    fi    
  if [[ $INSTANCE_ID == i-* ]]; then 
    TOTAL_INSTANCES=$((TOTAL_INSTANCES+1))
    CURRENT_INSTANCES["$INSTANCE_IP"]="$INSTANCE_ID|$INSTANCE_SG|$INSTANCE_IP"
    fi
  done
 


# generate a list of all security groups
declare -A CURRENT_SG_IPs
ALL_GROUPS=`ec2-describe-group`

 for GROUP in ${ALL_GROUPS[@]}
  do
    if [[ $GROUP == *GROUP* ]]
    then
      if [[ `echo $GROUP | awk '{print $2}'` == *sg-* ]]
        then
        GROUP_ID=`echo $GROUP | awk '{print $2}'`
        fi
      fi
 
    if [[ $GROUP == *PERMISSION* ]]
    then
      if [[ $GROUP == */32* ]]
        then
        IP_RULE=`echo $GROUP | awk '{print $10}'`
        IP_RULE=`echo $IP_RULE | rev | cut -c 4- | rev`
        CURRENT_SG_IPs["$IP_RULE"]="$IP_RULE"
      fi
    fi
  done


# generate a list of instance IPs not yet in security groups 
declare -A IPs_TO_ADD
for INSTANCE in "${CURRENT_INSTANCES[@]}"
  do
    INSTANCE_IP=`echo "$INSTANCE" | awk -F '|'  '{ print $3}'`
    if [ ! "${CURRENT_SG_IPs[$INSTANCE_IP]}" ]; then 
    IPs_TO_ADD["$INSTANCE_IP"]="$INSTANCE_IP"
    fi
  done


# generate a list of instance IPs in security groups but which are no longer running instances
declare -A IPs_TO_REMOVE
for INSTANCE_IP in "${CURRENT_SG_IPs[@]}"
  do
    if [ ! "${CURRENT_INSTANCES[$INSTANCE_IP]}" ]; then 
    IPs_TO_REMOVE["$INSTANCE_IP"]="$INSTANCE_IP"
    fi
  done

 for GROUP in ${ALL_GROUPS[@]}
  do
    if [[ $GROUP == *GROUP* ]]
    then
      if [[ `echo $GROUP | awk '{print $2}'` == *sg-* ]]
        then
        GROUP_ID=`echo $GROUP | awk '{print $2}'`

        # ADD ALL NEW
        for INSTANCE_IP in "${IPs_TO_ADD[@]}"
          do
          #echo "Adding IP $INSTANCE_IP/32 to $GROUP_ID"
          euca-authorize $GROUP_ID -P tcp -p 0-65535 -s $INSTANCE_IP/32
          done

        # REMOVE ALL OLD
        for INSTANCE_IP in "${IPs_TO_REMOVE[@]}"
          do
          #echo "Removing IP $INSTANCE_IP/32 from $GROUP_ID"
          euca-revoke $GROUP_ID -P tcp -p 0-65535 -s $INSTANCE_IP/32  
          done
        fi
      fi  

  done
