-- Clean and standardize DOB NOW job filing data
-- One row per job filing

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            job_filing_number,
            filing_status,
            borough,
            postcode,
            zip,
            council_district,
            filing_date,
            current_status_date,
            first_permit_date,
            approved_date,
            signoff_date,
            latitude,
            longitude
        ),

        -- Identifier
        CAST(job_filing_number AS STRING) AS job_filing_number,

        -- Filing status
        UPPER(TRIM(CAST(filing_status AS STRING))) AS filing_status,

        -- Standardize borough
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN'
        END AS borough,

        -- Property ZIP renamed to match the 311 staging table
        CASE
            WHEN LENGTH(TRIM(CAST(postcode AS STRING))) = 5
                THEN TRIM(CAST(postcode AS STRING))
            ELSE NULL
        END AS zip,

        -- Shared location field
        CAST(council_district AS STRING) AS council_district,

        -- Important dates
        SAFE_CAST(filing_date AS DATE) AS filing_date,
        SAFE_CAST(current_status_date AS DATE) AS current_status_date,
        SAFE_CAST(first_permit_date AS DATE) AS first_permit_date,
        SAFE_CAST(approved_date AS DATE) AS approved_date,
        SAFE_CAST(signoff_date AS DATE) AS signoff_date,

        -- Coordinates
        SAFE_CAST(latitude AS DECIMAL) AS latitude,
        SAFE_CAST(longitude AS DECIMAL) AS longitude,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Keep records with a valid filing identifier
    WHERE job_filing_number IS NOT NULL

    -- Remove duplicate filing numbers
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY job_filing_number
        ORDER BY SAFE_CAST(filing_date AS TIMESTAMP) DESC
    ) = 1
)

SELECT *
FROM cleaned