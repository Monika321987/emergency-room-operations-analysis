# Emergency Room Compliance & Operations Analysis

## 📊 Project Overview
This analysis of emergency department workflows bridges the gap between healthcare data engineering and operational clinical intelligence. Utilizing raw Electronic Health Record (EHR) data, I built an optimized data pipeline in PostgreSQL to compute critical clinical velocity metrics. After transforming and denormalizing backend transactional tables, I built a professional Tableau performance dashboard to track key metrics. This project accelerates executive decision-making by providing hospital leaders with the actionable insights needed to resolve ER bottlenecks, minimize compliance failures, and optimize patient flow.

 **[View Interactive Tableau Dashboard]([https://public.tableau.com/app/profile/monika.mitchell2582/viz/EmergencyRoomComplianceandOperationsAnalysis/Dashboard1?publish=yes])**

## 🚀 Key Features
* **Bottleneck Detection:** Identifies precise workflow constraints and queue delays within the Emergency Department.
* **Compliance Tracking:** Flags regulatory compliance failures against clinical targets.
* **Flow Optimization:** Exposes optimal care pathways to improve overall patient throughput.

### 🛠️ Tech Stack & Infrastructure
* **Database Management:** PostgreSQL (via pgAdmin 4)
* **Data Visualization:** Tableau Desktop / Tableau Public
* **Advanced SQL Techniques:** Window Functions (`MIN() OVER`), Common Table Expressions (CTEs), Conditional Logic (`CASE WHEN`), Data Denormalization

---

## 📈 Core Operational Key Performance Indicators (KPIs)
The SQL pipeline isolates bottlenecks across three distinct clinical operational phases:

### 1. Clinical SLA & Triage Compliance
* **The Metric:** Measures the precise minutes elapsed between a patient's initial Emergency Department registration (`intime`) and their absolute first recorded clinical assessment (vital sign check).
* **SLA Targets Applied:** Clinically aligned with Emergency Severity Index (ESI) acuity standards:
  * **ESI Level 1 (Resuscitation):** Must be seen within 5 minutes *(Delayed = High-Risk Alert)*
  * **ESI Level 2 (Emergent):** Must be seen within 15 minutes *(Delayed = High-Risk Alert)*
  * **ESI Level 3 (Urgent):** Must be seen within 30 minutes *(Delayed)*
  * **ESI Level 4 (Less Urgent):** Must be seen within 60 minutes *(Delayed)*
  * **ESI Level 5 (Non-Urgent):** Must be seen within 120 minutes *(Delayed)*

### 2. Inpatient Boarding Bottlenecks
* **The Metric:** Isolates admitted patients (`HOSPITAL MED/SURG`, `ICU`, `DIRECT ADMIT`, `TRANSFER`, `ADMITTED`) to calculate true boarding times.
* **Data Engineering Optimization:** Implemented strict `NULL` defaults for non-admitted patient populations within the SQL pipeline. This prevents discharged patient cohorts from artificially diluting or skewing true hospital admitting bottlenecks inside Tableau's aggregate average calculations.

### 3. Length of Stay (LOS) & Temporal Volatility
* **The Metric:** Total minutes per patient stay cross-referenced against cyclical arrival patterns (`arrival_hour` and `arrival_day_of_week`).
* **Business Value:** Provides hospital administrators with predictive operational visibility to forecast peak surge staffing requirements and mitigate Left Without Being Seen (LWBS) risks.

---

## 🖥️ Interactive Dashboard Preview

![Tableau Dashboard Preview](<img width="1499" height="1199" alt="Dashboard 1" src="https://github.com/user-attachments/assets/7deaff1a-d396-485d-a088-f1f8dceefe51" />
)

---

## 🔍 Visualized Insights & Operational Recommendations

### High-Acuity Delay Exposure (SLA Violations)
* **The Insight:** A significant percentage of triage level 1 and 2 patients experience initial vital sign capturing delays beyond their 5 and 15 minute compliance windows. These high-risk delays are heavily concentrated during shift change windows and mid-day surges.
* **The Recommendation:** Implement a "Rapid Assessment Triage" protocol during peak arrival hours (11:00 AM – 7:00 PM). Dedicate an autonomous intake nurse exclusively to immediate vital charting for arriving high-acuity squads.

### The Admitting Bottleneck (Boarding Hours vs. Discharges)
* **The Insight:** Total Length of Stay (LOS) spikes exponentially for patients tagged for inpatient admission compared to those discharged directly from the ED. The bottleneck is not caused by ED treatment speed, but by physical bed availability upstairs.
* **The Recommendation:** Establish an automated dashboard trigger for the hospital's main floor charge nurses. If an ED patient's "Inpatient Boarding Hours" cross 4 hours, an alert fires to prioritize and expedite inpatient discharges upstairs, creating immediate backfill capacity.

### Cyclical Surge Patterns & Staffing Misalignment
* **The Insight:** Temporal analysis reveals that total LOS and ESI delays spike predictably on Mondays and Tuesdays between 2:00 PM and 6:00 PM, heavily driven by specific arrival modes (e.g., walk-ins vs. ambulance transfers).
* **The Recommendation:** Dynamically realign nurse scheduling matrices. Shift part-time triage capacity from lower-volume weekend slots to create an overlapping "surge shift" on early-week afternoons.

---

## 🏗️ SQL Engineering Highlights
To inspect the full data pipeline, view the script in the [`database/queries.sql`](database/queries.sql) folder.

* **Advanced Window Functions:** Leveraged `MIN() OVER(PARTITION BY...)` to safely target earliest patient touchpoints without throwing standard SQL grouping or aggregation syntax errors.
* **Negative Interval Prevention:** Engineered a defensive `CASE WHEN` statement to capture and normalize edge cases where triage recording precedes official system registration timestamps, programmatically enforcing a 0-minute baseline to preserve dataset integrity.
* **Denormalized Analytical Layer:** Deployed a multi-CTE pipeline to output a clean, unified view optimized specifically for high-speed reporting engine ingestion.
