{{ config(
    enabled = var('claims_enabled', var('tuva_marts_enabled', false)) | as_bool
) }}

with member_months as (
    select 
        count(1) as member_months 
    from {{ ref('core__member_months') }}
)
,pkpy as (
select
    cast('encounters cost and utilization PKPY' as {{dbt.type_string()}}) as analytics_concept
    , enc.encounter_group
    , cast(enc.encounter_type as {{dbt.type_string()}}) as analytics_measure
    , count(enc.encounter_id) / avg(mm.member_months) * 12000 as data_source_value
from {{ ref('core__encounter') }} as enc
cross join member_months as mm
group by
    enc.encounter_group
    , enc.encounter_type
)
,paid_per as (
select
    cast('encounters cost and utilization paid per' as {{dbt.type_string()}}) as analytics_concept
    , enc.encounter_group
    , cast(enc.encounter_type as {{dbt.type_string()}}) as analytics_measure
    , sum(enc.paid_amount) / count(enc.encounter_id) as data_source_value
from {{ ref('core__encounter') }} as enc
cross join member_months as mm
group by
    enc.encounter_group
    , enc.encounter_type
)
select
    pkpy.*
    ,ref_data.analytics_value
    ,cast('{{ var('tuva_last_run')}}' as {{dbt.type_string()}}) as tuva_last_run
from pkpy
left join {{ ref('data_quality__reference_mart_analytics') }} ref_data on pkpy.analytics_concept = ref_data.analytics_concept and pkpy.analytics_measure = ref_data.analytics_measure
union all
select
    paid_per.*
    ,ref_data.analytics_value
    ,cast('{{ var('tuva_last_run')}}' as {{dbt.type_string()}}) as tuva_last_run
from paid_per
left join {{ ref('data_quality__reference_mart_analytics') }} ref_data on paid_per.analytics_concept = paid_per.analytics_concept and paid_per.analytics_measure = paid_per.analytics_measure