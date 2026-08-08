# Lab 14.01 — The budget, before anything else

**CORE · 40 min · $0**

## Context

This is the first lab of the module for one reason: a budget configured after
the first surprise bill has already failed at its job.

## The problem

### Part 1 — project and billing

Create a dedicated project for this track. Not a shared one — a project boundary
is the cleanest blast radius for cost, IAM and teardown.

```bash
gcloud projects create pulse-sre-$RANDOM --name="Pulse SRE Track"
gcloud billing projects link PROJECT_ID --billing-account=ACCOUNT_ID
```

1. Why a dedicated project rather than a folder or labels in an existing one?
2. What does the project boundary give you when it is time to tear down?

### Part 2 — the notification channel FIRST

Most people create the budget and stop. The budget is the easy half.

```bash
gcloud alpha monitoring channels create \
  --display-name="Pulse budget alerts" \
  --type=email \
  --channel-labels=email_address=YOUR_EMAIL
```

3. Check your inbox. What did GCP send, and what happens if you ignore it?
4. Verify the channel and confirm its state via the API.

Question 3 is the silent half of this module's break-fix: an unverified channel
receives nothing, and the budget looks correctly configured.

### Part 3 — the budget

```bash
gcloud billing budgets create \
  --billing-account=ACCOUNT_ID \
  --display-name="pulse-budget" \
  --budget-amount=30USD \
  --threshold-rule=percent=0.5 \
  --threshold-rule=percent=0.9 \
  --threshold-rule=percent=1.0 \
  --notifications-rule-monitoring-notification-channels=CHANNEL_ID
```

5. Confirm the channel is actually attached. Read the budget back and check
   `monitoringNotificationChannels` is not empty.

### Part 4 — understand what a budget is not

6. How long after spending does a budget alert fire? Why?
7. Can a budget **stop** spending? What would it take to build a hard cap?
8. What is the risk of that hard cap?

Question 8 matters: a function that disables billing on threshold will take your
production down. Right for a lab project, dangerous elsewhere.

### Part 5 — enable only what you need

```bash
gcloud services enable container.googleapis.com compute.googleapis.com
gcloud services list --enabled
```

9. Why not enable everything up front?

## Expected outcome

A dedicated project, a **verified** notification channel, a budget with the
channel attached and confirmed, and the four conceptual questions answered.

## Verification

```bash
gcloud billing budgets list --billing-account=ACCOUNT_ID \
  --format="value(notificationsRule.monitoringNotificationChannels)"
```

Must not be empty. If it is, you have reproduced half the break-fix already.
