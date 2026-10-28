Olist E-Commerce SQL Analytics
Project Overview
This project uses PostgreSQL to explore the Brazilian Olist e-commerce
dataset. The analysis examines sales trends, product-category
performance, payment methods, seller performance, delivery reliability,
and customer review scores.

The objective is to demonstrate practical SQL skills and turn query
results into business-focused observations that can support further
investigation and decision-making.
Business Questions
- How did delivered-order sales change over time?
- Which product categories generated the highest product sales value?
- Which payment methods accounted for the largest recorded payment
  value?
- How did delivery reliability change month to month?
- How do customer review scores differ between on-time and late
  deliveries?
- Which sellers recorded the highest product sales value?
Tools and Techniques
- PostgreSQL and pgAdmin
- SQL filtering, aggregation, and grouping
- Joins across orders, order items, products, payments, sellers, and
  reviews
- Common table expressions (CTEs)
- Date and time analysis
- Window functions, ranking, and month-over-month comparisons
- KPI calculation and charting
Selected Findings
The following observations are based on result tables shared during the
project work. They should be rechecked against the final exported
results before being used for formal business decisions.
- Product categories: Health & Beauty recorded R$1,233,131.72 in
  product sales value in the category results reviewed. Watches &
  Gifts followed with R$1,166,176.98.
- Payment methods: Credit-card records accounted for
  R$12,542,084.19 in total recorded payment value in the
  payment-method analysis.
- Delivery reliability: The monthly on-time delivery rate was
  85.69% in November 2017 in the delivery analysis reviewed.
- Customer reviews: The average review score was 4.29 for on-time
  deliveries and 2.57 for late deliveries in the comparison reviewed.
  This indicates an association in the analyzed records, not proof
  that delivery timing alone caused the difference.
Metric note: Product sales value is not profit. Payment value and
item sales value are different measures and should not be treated as
interchangeable.
Visualization
Monthly Sales Trend

The chart displays monthly product sales value over the period
represented in the available results. It can help identify growth,
fluctuations, and periods that may deserve further investigation.
Repository Contents
- sql/olist_full_analysis.sql --- numbered PostgreSQL analyses.
- sql/README.md --- notes about the SQL folder.
- charts/01_monthly_sales.png --- monthly sales chart.
- charts/README.md --- notes about the charts folder.
Dataset
The project uses the Brazilian E-Commerce Public Dataset by Olist,
available on Kaggle:

https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

The dataset contains linked e-commerce tables, including orders, order
items, customers, products, payments, sellers, reviews, and geolocation
information.
Limitations
- Product sales value should not be interpreted as profit or net
  accounting revenue.
- Findings depend on the tables, filters, date fields, and metric
  definitions used in the queries.
- A relationship between delivery performance and review scores does
  not establish causation.
- The reported figures should be verified against the final database
  outputs before publication or business use.
- The dataset describes historical activity and may not represent
  current marketplace conditions.
Author
Olafare-analytics
Data Analyst | SQL | Business Intelligence | Data Visualization
