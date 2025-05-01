> **Designed for AWS CloudShell**  
These scripts are intended to run directly in [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/).  
They may also work in other local or remote environments with the AWS CLI, `jq`, and proper credentials set up.  
However, this README does **not cover** authentication or CLI setup outside CloudShell.

# AWS Tools

A growing collection of CLI-based scripts and utilities for managing AWS services more efficiently.

This repository is designed to group together automation helpers across various AWS areas — from EC2 to CloudWatch, IAM to S3 — to simplify repeated operational tasks and integrate with external systems like Slack, Zapier, and others.

## Available Toolsets

### CloudWatch

Scripts for monitoring EC2 instance health using CloudWatch alarms and integrating with Slack via Zapier webhooks.

[View CloudWatch Tools ➜](./CloudWatch/README.md)

---

## Roadmap

Areas of coverage will eventually include:

- EC2 lifecycle automation
- IAM credential/reporting utilities
- Lambda deployment helpers
- S3 sync and archival tools
- SNS/SQS message flow monitoring
- And more...

Stay tuned as the repo evolves.
