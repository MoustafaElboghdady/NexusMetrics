# NexusMetrics — SaaS Subscription Analytics (Practice Project)

## Overview

This is a self-training project built to practice core subscription business metrics using a realistic, synthetic SaaS dataset. The goal was not just to calculate numbers, but to understand the business logic behind each metric well enough to explain it, defend it, and catch errors in it.

## Purpose

The project focuses on hands-on mastery of the metrics every subscription business tracks:

- **MRR** (Monthly Recurring Revenue) and the MRR Waterfall (New / Expansion / Contraction / Churned)
- **Churn Rate**
- **CRR** (Customer Retention Rate)
- **GRR** (Gross Revenue Retention)
- **NRR** (Net Revenue Retention)
- **ARPU** (Average Revenue Per User)
- **CAC** (Customer Acquisition Cost)
- **CLTV** (Customer Lifetime Value) — both actual and estimated

Each metric was tackled as its own problem: understand the business question first, then build the query, then sanity-check the result against what actually makes business sense.

## Dataset

A synthetic dataset covering Jan 2020 – Aug 2026, built to mimic real SaaS growth and churn dynamics: a growing customer base, tenure-based churn (higher risk early on, lower for long-tenured and higher-tier customers), plan upgrades/downgrades, and win-back/reactivation cases. Two tables: `customers` (signup, acquisition channel, cost, region, churn status) and `transactions` (one row per billing event: new subscription, renewal, upgrade, downgrade, cancellation, reactivation).

## Workflow

The project follows a full analyst workflow rather than a single notebook:

1. **Data generation** — synthetic data created in Python
2. **Loading** — data pushed into a **PostgreSQL** database
3. **Querying** — all metric logic written and validated in **SQL** (CTEs, window functions, cohort logic)
4. **Analysis & visualization** — results pulled back into **Python** (pandas) for cleaning, aggregation, and charting

This Python → SQL → Python loop was intentional — the goal was to practice moving data between tools the way a real analyst would, not just solve everything in one environment.

## What This Project Emphasizes

- Business logic before code: every metric started with "what question is this actually answering?" before any SQL was written
- Debugging as a skill: several of the hardest moments in this project weren't syntax errors, they were queries that ran fine but returned numbers that didn't make business sense — and tracing *why*
- Consistency in definitions: e.g. making sure the time unit used to measure retention matches the time unit used to define the cohort, rather than mixing granularities
- SQL specifics practiced: CTEs, `LAG()` / `FIRST_VALUE()` window functions, `PARTITION BY`, cohort-based filtering, safe division (`NULLIF`), and building reusable views

## Note

This README is a summary and walkthrough of the project's thinking and structure. Full queries, Python scripts, and visualizations are included in the repository files.
