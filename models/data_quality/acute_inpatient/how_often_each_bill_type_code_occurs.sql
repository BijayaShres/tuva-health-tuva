{{ config(
    enabled = var('claims_enabled', False)
) }}

with add_count_of_occurrences as (

    select
          claim_id
        , bill_type_code
        , count(*) as occurrences
    from {{ ref('valid_values') }}
    where valid_bill_type_code = 1
    group by
          claim_id
        , bill_type_code

)

, add_ranking_from_high_to_low_occurrences as (

    select
          claim_id
        , bill_type_code
        , occurrences
        , row_number() over (
            partition by claim_id
            order by occurrences desc
        ) as ranking
    from add_count_of_occurrences

)

select
      claim_id
    , bill_type_code
    , occurrences
    , ranking
from add_ranking_from_high_to_low_occurrences
