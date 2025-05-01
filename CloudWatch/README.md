> **Designed for AWS CloudShell**  
These scripts are intended to run directly in [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/).  
They may also work in other local or remote environments with the AWS CLI, `jq`, and proper credentials set up.  
However, this README does **not cover** authentication or CLI setup outside CloudShell.

# CloudWatch Tools

## Overview

This directory allows AWS CloudWatch management for a narrow use case:
- When an EC2 instance **fails** a status check
- The CloudWatch Alarm automatically **reboots** the instance

In addition, a second script can also set up a notification of the ALARM or OK status change, using SNS against a Zapier Webhook which is also configured to post to a Slack channel. 

## Scripts

| Script | Purpose |
|--------|---------|
| `create_ec2_statuscheck_reboot_alarm.sh` | Creates a CloudWatch alarm that reboots EC2 and notifies |
| `add_zapier_to_alarm.sh` | Adds Slack/Zapier notifications to any existing alarm |

---

### `create_ec2_statuscheck_reboot_alarm.sh`

Creates a new CloudWatch alarm that:
- Triggers on `StatusCheckFailed_Instance >= 1`
- Automatically **reboots the instance**

**Usage:**

```bash
./create_ec2_statuscheck_reboot_alarm.sh <INSTANCE_ID> <ALARM_NAME> <REGION>
```

---

### `add_zapier_to_alarm.sh`

This script:
- Creates a **dedicated SNS topic per Zapier webhook**
- Subscribes to the Zapier webhook (if not already subscribed)
- Updates an existing CloudWatch alarm to:
    - Notify when the state changes to `ALARM`
    - Notify when the state changes to `OK`
- Ensures no duplicate actions are applied (re-entrant safe)

You should first create a Zapier Webhook. See [Creating a Webhook Zap in Zapier](#creating-a-webhook-zap-in-zapier). 

#### Topic Isolation by Webhook

Each webhook URL generates a **unique SNS topic name**, based on a short hash of the URL. This guarantees:

- Separate topics for separate Slack destinations
- Easy identification of test vs. prod hooks
- No cross-talk between unrelated alerts

**Example topic name:** `cw-to-zapier-b7f3d1c2` (derived from a SHA1 hash of the webhook URL)

#### Usage

```bash
./add_zapier_to_alarm.sh <ALARM_NAME> <REGION> <ZAPIER_WEBHOOK_URL>
```

#### Example

```bash
./add_zapier_to_alarm.sh FordPrefectRebootOnStatusFail us-east-1 https://hooks.zapier.com/hooks/catch/64788/2pqt81k/
```

---

## Manual Confirmation (One-Time Per Topic)

Each SNS topic still requires a one-time manual confirmation step for Zapier to accept the subscription.

When the script runs for the first time with a new webhook:
- AWS sends a `SubscriptionConfirmation` message to Zapier
- You'll need to confirm the SNS subscription manually:

**Steps to confirm:**

1. In Zapier, view **Zap history** or run the **“Test Trigger”** mode
2. Find the **`SubscriptionConfirmation`** event
3. Copy the `SubscribeURL` field
4. Paste it in your browser and hit **Enter**
5. You’ll see: _“Subscription Confirmed”_

After that, Zapier will receive all future alerts for that topic.

## Creating a Webhook Zap in Zapier

To connect your CloudWatch alarm notifications to Slack, follow these steps to create a Zap that receives the SNS webhook and posts to a Slack channel:

1. **Go to [zapier.com](https://zapier.com) and create a new Zap**
2. **Trigger:**
  - Choose: **Webhooks by Zapier**
  - Event: **Catch Hook**
  - Click **Continue**
  - Zapier will give you a unique webhook URL (e.g., `https://hooks.zapier.com/hooks/catch/...`)
  - Copy this URL — you'll use it in the `add_zapier_to_alarm.sh` script
3. **Test the webhook**
  - Keep the **“Test trigger”** screen open
  - Run the `add_zapier_to_alarm.sh` script
  - Zapier should catch a `SubscriptionConfirmation` or `ALARM` payload
4. **Action:**
  - Choose: **Slack**
  - Event: **Send Channel Message**
  - Connect your Slack account
  - Choose a target channel
  - Customize the message using fields from the webhook

**Suggested Slack Message Template:**

```markdown
*CloudWatch Event*
*{{Timestamp}}*
*Subject:* {{Subject}}
*Reason:* {{Message__NewStateReason}}
*Instance:* {{Message__Trigger__Dimensions__0__value}}
```

> Use Zapier’s field selector to choose these fields — don’t copy-paste raw keys.

5. **Turn the Zap on**

You’re now set up to receive real-time Slack alerts when your EC2 instance fails (or recovers).

### Testing the SNS → Zapier → Slack Flow

To test your SNS-to-Zapier-to-Slack integration without waiting for a real alarm event:

1. Determine the SNS topic name used for your webhook.  
   It follows this pattern:

   ```bash
   cw-to-zapier-$(echo <ZAPIER_WEBHOOK_URL> | sha1sum | cut -c1-8)
   ```

   For example: (replacing the below with your webhook)

   ```bash
   echo -n "https://hooks.zapier.com/hooks/catch/99999/xxxxxxx/" | sha1sum | cut -c1-8
   # Output: b7f3d1c2 → topic name: cw-to-zapier-b7f3d1c2
   ```

2. Use the topic name to publish a manual test event:

```bash
aws sns publish \
  --topic-arn arn:aws:sns:<REGION>:<ACCOUNT_ID>:cw-to-zapier-<HASH> \
  --subject "ALARM: Manual Test" \
  --message '{
    "AlarmName": "ManualTestAlarm",
    "NewStateValue": "ALARM",
    "NewStateReason": "Manual test event.",
    "StateChangeTime": "2025-05-01T00:00:00Z",
    "Trigger": {
      "Dimensions": [
        { "name": "InstanceId", "value": "i-0123456789abcdef0" }
      ]
    }
  }'
```

3. Check Zapier → Task History → Slack to verify the message was posted.

