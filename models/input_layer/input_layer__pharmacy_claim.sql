{{ config(
     enabled = var('claims_preprocessing_enabled',var('claims_enabled',var('tuva_marts_enabled',False)))
 | as_bool
   )
}}
SELECT *
FROM {{ ref('pharmacy_claim') }}
