# Practice Case: NexusMetrics (B2B SaaS Subscription Analytics)

## Scenario
NexusMetrics sells a subscription analytics tool on 3 tiers, billed monthly:

| Plan | Price/month |
|---|---|
| Basic | $29 |
| Pro | $59 |
| Enterprise | $149 |

Data covers **Jan 2020 – Aug 2026**. 405 customers, ~10,400 transactions.
The CEO wants a metrics review before the board meeting. You're the analyst.

## Files

**customers.csv** — one row per customer
- `customer_id`
- `signup_date`
- `acquisition_channel` (Paid Search, Organic Search, Referral, Social Media, Email Campaign, Partnership)
- `acquisition_cost` (marketing $ spent to acquire this customer)
- `region` (North America, Europe, MENA, Asia Pacific, Latin America)
- `initial_plan`
- `final_status` (Active / Churned, as of 2026-08-17)
- `churned_at_least_once` (Yes/No)
- `first_churn_date`
- `reactivated` (Yes/No — came back after cancelling)
- `reactivation_date`

**transactions.csv** — one row per billing event
- `transaction_id`
- `customer_id`
- `transaction_date`
- `transaction_type` (New Subscription, Renewal, Upgrade, Downgrade, Reactivation, Cancellation)
- `plan_tier`
- `amount` (0 for Cancellation rows — that row just marks the churn event)

Load both into PostgreSQL and join on `customer_id`. Use Power BI or Excel for the visuals.

---

## Questions

### MRR (Monthly Recurring Revenue)
1. Build a monthly MRR trend for the full period. Where are the biggest jumps or drops? >> DONE
2. Break MRR down by plan tier, by month. Which tier drives most of current MRR? >>DONE
3. Split MRR into New, Expansion (upgrades), Contraction (downgrades), and Churned MRR for each month. This is a standard "MRR waterfall" — build it.

### Churn Rate
4. Calculate monthly customer churn rate (% of active customers at start of month who cancel that month). >> DONE
5. Is churn rate higher for Basic vs Pro vs Enterprise? Show it as a table. >> DONE
6. Which acquisition channel has the worst churn rate? Does that change your view of which channel is "best"? >> DONE

### CRR (Customer Retention Rate)
7. Calculate CRR for each calendar year (2021–2025). Formula: customers at end of period who were also active at start, divided by customers active at start.
8. Compare CRR across regions. Any region standing out? >> DONE

### GRR (Gross Revenue Retention)
9. Pick a cohort — customers active on 2024-01-01. Track their revenue through 2024-12-31, counting downgrades and churn as losses but ignoring upgrades. What's the GRR? >> DONE
10. Why can GRR never exceed 100%? Confirm this holds in your calculation. >> DONE

### NRR (Net Revenue Retention)
11. Same cohort as Q9. Now include upgrade revenue. What's the NRR? >> DONE
12. NRR vs GRR — what's the gap telling you about the business? Is expansion revenue covering churn losses? >> DONE

### ARPU (Average Revenue Per User)
13. Calculate ARPU by month for the whole customer base. >> DONE
14. Calculate ARPU by plan tier and by region. Where's ARPU growing fastest? >> DONE

### CAC (Customer Acquisition Cost)
15. Calculate blended CAC (total acquisition_cost / total new customers) by year. Is CAC trending up or down? >> DONE
16. Calculate CAC by acquisition_channel. Which channel is cheapest? Which brings the least churn-prone customers (tie back to Q6)? >> DONE

### CLTV (Customer Lifetime Value)
17. For churned customers only, calculate actual realized lifetime value (sum of all their payments). What's the average? >> DONE
18. Estimate CLTV using the formula: ARPU × Average Customer Lifespan (or ARPU / Churn Rate). Compare this estimate to your Q17 actual number. >> DONE
19. Calculate CLTV : CAC ratio by channel. Which channel is actually the best investment once you account for both cost and value?

### Capstone (combine everything)
20. Build a one-page executive summary: current MRR, MoM growth %, churn rate, NRR, blended CAC, CLTV:CAC ratio. Flag anything that should worry the board.
21. Segment customers into cohorts by signup quarter (e.g. 2023-Q1, 2023-Q2...). Build a cohort retention curve (% of each cohort still active at month 1, 2, 3... after signup). This is the classic SaaS cohort chart.

---

## Notes
- No answers provided on purpose — this is for practice.
- Amounts are exact plan prices, no proration, so the math stays clean.
- `Cancellation` rows have `amount = 0` — exclude them from revenue sums, but use them to identify churn dates.
