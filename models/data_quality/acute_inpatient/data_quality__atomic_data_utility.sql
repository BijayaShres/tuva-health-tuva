{{ config(
    enabled = var('claims_enabled', False)
) }}

/*yet to add eligibility_atomic_data_utility*/
with medical_claim_atomic_data_utility as (
    
    select
          table_name
        , field
        , claim_type
        , missing_count
        , missing_perc
        , invalid_count
        , invalid_perc
        , duplicated_count
        , duplicated_perc
    from {{ ref('data_quality__medical_claim_atomic_data_utility') }}

)

, pharmacy_claim_atomic_data_utility as (

    select
          table_name
        , field
        , claim_type
        , missing_count
        , missing_perc
        , invalid_count
        , invalid_perc
        , duplicated_count
        , duplicated_perc
    from {{ ref('data_quality__pharmacy_claim_atomic_data_utility') }}

)

, final as (

    select * from medical_claim_atomic_data_utility

    union all

    select * from pharmacy_claim_atomic_data_utility

)

select
      table_name
    , field
    , claim_type
    , missing_count
    , missing_perc
    , invalid_count
    , invalid_perc
    , duplicated_count
    , duplicated_perc
    , '{{ var('tuva_last_run')}}' as tuva_last_run
from final
