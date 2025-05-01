#!/bin/bash

# === USAGE CHECK ===
if [ $# -ne 3 ]; then
  echo "Usage: $0 <ALARM_NAME> <REGION> <ZAPIER_WEBHOOK_URL>"
  exit 1
fi

ALARM_NAME="$1"
REGION="$2"
ZAPIER_WEBHOOK_URL="$3"

# Create a unique SNS topic name based on the Zapier webhook URL
SNS_TOPIC_NAME="cw-to-zapier-$(echo $ZAPIER_WEBHOOK_URL | sha1sum | cut -c1-8)"
SNS_TOPIC_ARN=$(aws sns create-topic --name "$SNS_TOPIC_NAME" --region "$REGION" --query 'TopicArn' --output text)

# === SUBSCRIBE ZAPIER WEBHOOK IF NEEDED ===
if ! aws sns list-subscriptions-by-topic --topic-arn "$SNS_TOPIC_ARN" --region "$REGION" | grep -q "$ZAPIER_WEBHOOK_URL"; then
  aws sns subscribe     --topic-arn "$SNS_TOPIC_ARN"     --protocol https     --notification-endpoint "$ZAPIER_WEBHOOK_URL"     --region "$REGION"
  echo "🔗 Subscribed Zapier webhook to SNS topic."
else
  echo "✅ Zapier webhook already subscribed to SNS topic."
fi

# === GET EXISTING ALARM DETAILS ===
ALARM_DEF=$(aws cloudwatch describe-alarms   --alarm-names "$ALARM_NAME"   --region "$REGION"   --query 'MetricAlarms[0]')

EXISTING_ALARM_ACTIONS=$(echo "$ALARM_DEF" | jq -r '.AlarmActions[]?')
EXISTING_OK_ACTIONS=$(echo "$ALARM_DEF" | jq -r '.OKActions[]?')

ALARM_ACTION_LIST=()
OK_ACTION_LIST=()

FOUND_ALARM=0
for action in $EXISTING_ALARM_ACTIONS; do
  ALARM_ACTION_LIST+=("$action")
  [[ "$action" == "$SNS_TOPIC_ARN" ]] && FOUND_ALARM=1
done
if [ $FOUND_ALARM -eq 0 ]; then
  ALARM_ACTION_LIST+=("$SNS_TOPIC_ARN")
  echo "➕ Added SNS topic to alarm-actions."
else
  echo "ℹ️ SNS topic already present in alarm-actions. No change needed."
fi

FOUND_OK=0
for action in $EXISTING_OK_ACTIONS; do
  OK_ACTION_LIST+=("$action")
  [[ "$action" == "$SNS_TOPIC_ARN" ]] && FOUND_OK=1
done
if [ $FOUND_OK -eq 0 ]; then
  OK_ACTION_LIST+=("$SNS_TOPIC_ARN")
  echo "➕ Added SNS topic to ok-actions."
else
  echo "ℹ️ SNS topic already present in ok-actions. No change needed."
fi

aws cloudwatch put-metric-alarm   \
  --alarm-name "$ALARM_NAME"   \
  --metric-name "$(echo "$ALARM_DEF" | jq -r '.MetricName')"   \
  --namespace "$(echo "$ALARM_DEF" | jq -r '.Namespace')"   \
  --statistic "$(echo "$ALARM_DEF" | jq -r '.Statistic')"   \
  --period "$(echo "$ALARM_DEF" | jq -r '.Period')"   \
  --evaluation-periods "$(echo "$ALARM_DEF" | jq -r '.EvaluationPeriods')"   \
  --threshold "$(echo "$ALARM_DEF" | jq -r '.Threshold')"   \
  --comparison-operator "$(echo "$ALARM_DEF" | jq -r '.ComparisonOperator')"   \
  --dimensions "$(echo "$ALARM_DEF" | jq -c '.Dimensions')"   \
  --treat-missing-data "$(echo "$ALARM_DEF" | jq -r '.TreatMissingData')"   \
  --alarm-actions "${ALARM_ACTION_LIST[@]}"   \
  --ok-actions "${OK_ACTION_LIST[@]}"   \
  --region "$REGION"

echo "✅ Alarm '$ALARM_NAME' updated successfully with alarm and OK notifications."
