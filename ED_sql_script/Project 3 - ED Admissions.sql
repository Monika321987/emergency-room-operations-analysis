CREATE TABLE edstays(
 	subject_id INT NOT NULL,
    hadm_id INT,
    stay_id INT PRIMARY KEY,
    intime TIMESTAMP NOT NULL,
    outime TIMESTAMP NOT NULL,
    gender VARCHAR(10),
    race VARCHAR(100),
    arrival_transport VARCHAR(100),
    disposition VARCHAR(100)
);

CREATE TABLE triage (
    subject_id INT NOT NULL,
    stay_id INT PRIMARY KEY,
    temperature NUMERIC(5,2),
    heartrate NUMERIC(4,1),
    resprate NUMERIC(4,1),
    o2sat NUMERIC(4,1),
    sbp NUMERIC(4,1),
    dbp NUMERIC(4,1),
    pain VARCHAR(50),
	acuity INT, -- This is your 1-5 triage score
    chiefcomplaint TEXT
);

CREATE TABLE vitalsign (
    subject_id INT NOT NULL,
    stay_id INT REFERENCES edstays(stay_id),
    charttime TIMESTAMP NOT NULL,
    temperature NUMERIC,
    heartrate NUMERIC,
    resprate NUMERIC,
    o2sat NUMERIC,
    sbp NUMERIC,
    dbp NUMERIC,
    rhythm VARCHAR(100),
    -- Composite unique key because a single stay has multiple vital checks over time
	pain VARCHAR(50),
    PRIMARY KEY (stay_id, charttime) 
);

Copy edstays FROM 'C:\Users\Public\edstays.csv' WITH (FORMAT CSV,HEADER, NULL '');
Copy triage FROM 'C:\Users\Public\triage.csv' WITH (FORMAT CSV,HEADER, NULL '');
Copy vitalsign FROM 'C:\Users\Public\vitalsign.csv' WITH (FORMAT CSV,HEADER, NULL '');


-- ============================================================================
-- STEP 1: BASE TIMESTAMPS & CLINICAL TRIAGE
-- ============================================================================
WITH base_ed_stays AS (
    SELECT 
        e.subject_id,
        e.stay_id,
        e.arrival_transport,
        e.disposition,
        e.intime AS arrival_time,
        e.outime AS departure_time,
        COALESCE(t.acuity, 5) AS triage_score -- ESI Level (Defaulting to 5 if missing)
    FROM edstays e
    LEFT JOIN triage t ON e.stay_id = t.stay_id
    WHERE e.intime IS NOT NULL AND e.outime IS NOT NULL
),

-- ANALYSIS A: Left Without Being Seen (LWBS) & Base Length of Stay
analysis_a_los AS (
    SELECT 
        stay_id,
        EXTRACT(HOUR FROM arrival_time) AS arrival_hour,
        TRIM(TO_CHAR(arrival_time, 'Day')) AS arrival_day_of_week,
        EXTRACT(EPOCH FROM (departure_time - arrival_time)) / 60 AS total_los_minutes
    FROM base_ed_stays
),

-- ANALYSIS B (Step 1): Find the first vital sign timestamp per stay using Window Functions (Avoids syntax errors)
first_vitals AS (
    SELECT 
        b.stay_id,
        b.triage_score,
        -- Window function to safely isolate the absolute first clinical touchpoint
        MIN(v.charttime) OVER(PARTITION BY b.stay_id) AS first_vital_time,
        b.arrival_time
    FROM base_ed_stays b
    LEFT JOIN vitalsign v ON b.stay_id = v.stay_id
),

-- Eliminate duplicates caused by the window function grouping
first_vitals_dedup AS (
    SELECT DISTINCT 
        stay_id,
        triage_score,
        -- Protect against negative intervals if triage occurs right before official registration
        CASE 
            WHEN first_vital_time IS NULL THEN NULL
            WHEN first_vital_time < arrival_time THEN 0 
            ELSE EXTRACT(EPOCH FROM (first_vital_time - arrival_time)) / 60 
        END AS minutes_to_initial_assessment
    FROM first_vitals
),

-- ANALYSIS B (Step 2): Clinical Safety SLAs
analysis_b_clinical_sla AS (
    SELECT 
        stay_id,
        minutes_to_initial_assessment,
        CASE 
            WHEN minutes_to_initial_assessment IS NULL THEN 'MISSING ASSESSMENT'
            WHEN triage_score = 1 AND minutes_to_initial_assessment > 5 THEN 'DELAY: High-Risk'
            WHEN triage_score = 2 AND minutes_to_initial_assessment > 15 THEN 'DELAY: High-Risk'
            WHEN triage_score = 3 AND minutes_to_initial_assessment > 30 THEN 'DELAY'
            WHEN triage_score = 4 AND minutes_to_initial_assessment > 60 THEN 'DELAY'
            WHEN triage_score = 5 AND minutes_to_initial_assessment > 120 THEN 'DELAY'
            ELSE 'COMPLIANT'
        END AS triage_compliance_status
    FROM first_vitals_dedup
),

-- ANALYSIS C: Boarding Bottlenecks (ED to Inpatient Inefficiencies)
analysis_c_boarding AS (
    SELECT 
        stay_id,
        CASE 
            WHEN disposition IN ('HOSPITAL MED/SURG', 'ICU', 'DIRECT ADMIT', 'TRANSFER', 'ADMITTED') THEN 1 
            ELSE 0 
        END AS is_admitted_patient,
        CASE 
            WHEN disposition IN ('HOSPITAL MED/SURG', 'ICU', 'DIRECT ADMIT', 'TRANSFER', 'ADMITTED') 
            THEN EXTRACT(EPOCH FROM (departure_time - arrival_time)) / 3600 
            ELSE NULL -- Changed from 0 to NULL so it won't ruin your averages in Tableau
        END AS inpatient_boarding_hours
    FROM base_ed_stays
)

-- ============================================================================
-- STEP 3: FINAL DE-NORMALIZED OUTPUT FOR TABLEAU
-- ============================================================================
SELECT 
    -- Baseline Dimensions
    b.subject_id,
    b.stay_id,
    b.arrival_transport,
    b.triage_score,
    b.disposition,
    b.arrival_time,
    b.departure_time,
    
    -- Analysis A Metrics
    a.arrival_hour,
    a.arrival_day_of_week,
    a.total_los_minutes,
    
    -- Analysis B Metrics
    v.minutes_to_initial_assessment,
    v.triage_compliance_status,
    
    -- Analysis C Metrics
    c.is_admitted_patient,
    c.inpatient_boarding_hours
FROM base_ed_stays b
JOIN analysis_a_los a ON b.stay_id = a.stay_id
JOIN analysis_b_clinical_sla v ON b.stay_id = v.stay_id
JOIN analysis_c_boarding c ON b.stay_id = c.stay_id;

