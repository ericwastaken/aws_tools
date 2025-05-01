#!/bin/bash

# === CHECK ARGUMENTS ===
if [ $# -ne 3 ]; then
  echo "Usage: $0 <INSTANCE_ID> <ALARM_NAME> <REGION>"
  exit 1
fi

INSTANCE_ID="$1"
ALARM_NAME="$2"
REGION="$3"

aws cloudwatch put-metric-alarm   \
  --alarm-name "$ALARM_NAME"   \
  --metric-name StatusCheckFailed_Instance   \
  --namespace AWS/EC2   \
  --statistic Minimum   \
  --period 300   \
  --evaluation-periods 2   \
  --threshold 1   \
  --comparison-operator GreaterThanOrEqualToThreshold   \
  --dimensions Name=InstanceId,Value="$INSTANCE_ID"   \
  --alarm-actions "arn:aws:automate:$REGION:ec2:reboot"   \
  --treat-missing-data notBreaching   \
  --region "$REGION"

echo "✅ Alarm '$ALARM_NAME' created for instance '$INSTANCE_ID' in region '$REGION'."
