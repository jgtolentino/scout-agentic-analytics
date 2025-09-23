

SELECT
    canonical_id,
    transaction_id,
    store_id,
    device_id,
    transaction_date,
    transaction_time,
    basket_size,
    total_amount,
    payment_method,
    customer_type,
    municipality,
    barangay,
    latitude,
    longitude,
    data_source,
    _source_file,
    _ingested_at,
    loaded_at
FROM bronze.transactions