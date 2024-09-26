{{ config(
     enabled = var('quality_measures_enabled',var('claims_enabled',var('clinical_enabled',var('tuva_marts_enabled',False)))) | as_bool
   )
}}

/*
- This query calculates the proportion of days covered (PDC) for patients
  based on their medication fill records, ensuring that any overlaps or
  periods extending beyond the performance period are properly handled. 
- It then filters for patients with a PDC of 80% or higher.
*/

with denominator as (

    select
          patient_id
        , dispensing_date
        , first_dispensing_date
        , days_supply
        , performance_period_begin
        , performance_period_end
        , measure_id
        , measure_name
        , measure_version
    from {{ ref('quality_measures__int_adhras_denominator') }}

)

-- Updates days supply by capping it at the performance period end date if it exceeds that period
, patient_with_updated_days_supply as (

    select
          patient_id
        , dispensing_date
        , days_supply
        , performance_period_end
        , case 
            when {{ dbt.dateadd (
                        datepart="day"
                        , interval='days_supply'
                        , from_date_or_timestamp= 'dispensing_date'
                    ) 
                }} > performance_period_end
            then ( days_supply - 
                    {{ datediff (
                          'performance_period_end'
                        , dbt.dateadd(
                              datepart="day"
                            , interval='days_supply'
                            , from_date_or_timestamp = 'dispensing_date'
                            ) 
                    
                        , 'day'
                        ) 
                    }} 
                )
            else days_supply
        end as updated_days_supply
    from denominator

)

-- Adds end date for each fill, adjusting if it exceeds the performance period, and calculates the lead date of fill_date
, patient_with_end_date_lead_date as (
    
    select
          patient_id
        , dispensing_date
        , updated_days_supply
        , case 
            when ({{ dbt.dateadd(
                    datepart="day"
                    , interval="days_supply"
                    , from_date_or_timestamp= "dispensing_date"
                ) 
                }}) > performance_period_end
            then 
                performance_period_end
            else
                {{ dbt.dateadd(
                    datepart="day"
                    , interval="days_supply"
                    , from_date_or_timestamp= "dispensing_date"
                ) 
                }}
            end as end_date
        , lead(dispensing_date) over(partition by patient_id order by dispensing_date) as lead_date
    from patient_with_updated_days_supply

)

-- Replaces null lead dates with the end date
, patient_with_updated_dates as (

    select
          patient_id
        , dispensing_date
        , updated_days_supply
        , end_date
        , coalesce(lead_date, end_date) as updated_lead_date
    from patient_with_end_date_lead_date

)

-- Calculates overlap between fills by comparing the end date and the next dispensing date
, patient_with_overlap as (

    select
          patient_id
        , dispensing_date
        , updated_days_supply
        , end_date
        , updated_lead_date
        , case 
            when {{ datediff('updated_lead_date', 'end_date', 'day') }} < 0 
            then 0 
            else {{ datediff('updated_lead_date', 'end_date', 'day') }} 
            end as overlap
    from patient_with_updated_dates

)

--Sums the days covered by medications for each patient
, patient_with_days_covered as (

    select
          patient_id
        , sum(updated_days_supply) - sum(overlap) as days_covered
    from patient_with_overlap
    group by patient_id
    order by patient_id

)

--Calculates the treatment period days based on the first dispensing date
, patient_with_treatment_period_days as (
    select
          patient_id
        , {{ datediff('first_dispensing_date', 'performance_period_end', 'day') }} as treatment_period_days
    from denominator

)

-- Computes the PDC percentage for each patient
, patient_with_pdc as (

    select
          days_covered_patient.patient_id
        , days_covered*100/treatment_period_days as pdc
    from patient_with_days_covered as days_covered_patient
    inner join patient_with_treatment_period_days as treatment_period_days_patient
        on days_covered_patient.patient_id = treatment_period_days_patient.patient_id

)

--Selects valid patients whose PDC is 80% or higher
, valid_patients as (

    select 
          patient_with_pdc.patient_id
        , denominator.first_dispensing_date
        , denominator.performance_period_begin
        , denominator.performance_period_end
        , denominator.measure_id
        , denominator.measure_name
        , denominator.measure_version
        , pdc 
        , 1 as numerator_flag
    from patient_with_pdc 
    inner join denominator 
        on patient_with_pdc.patient_id = denominator.patient_id 
    where cast( pdc as {{ dbt.type_numeric() }} ) >= 80.0

)

, add_data_types as (

    select
          cast(patient_id as {{ dbt.type_string() }}) as patient_id
        , cast(performance_period_begin as date) as performance_period_begin
        , cast(performance_period_end as date) as performance_period_end
        , cast(measure_id as {{ dbt.type_string() }}) as measure_id
        , cast(measure_name as {{ dbt.type_string() }}) as measure_name
        , cast(measure_version as {{ dbt.type_string() }}) as measure_version
        , cast(first_dispensing_date as date) as evidence_date
        , cast(pdc as {{ dbt.type_numeric() }}) as evidence_value
        , cast(numerator_flag as integer) as numerator_flag
    from valid_patients

)

select 
      patient_id
    , performance_period_begin
    , performance_period_end
    , measure_id
    , measure_name
    , measure_version
    , evidence_date
    , evidence_value
    , numerator_flag
from add_data_types
