# clean_validate_scout45.py  — full 45-col schema with auto-fixes
import pandas as pd, numpy as np, sys, json

inp  = sys.argv[1]  # in  : out/flat/flat_dataframe_complete_45col.csv
outp = sys.argv[2]  # out : out/flat/flat_dataframe_complete_45col.cleaned.csv
elog = sys.argv[3]  # log : out/flat/flat_dataframe_complete_45col.errors.csv

df = pd.read_csv(inp, dtype=str).apply(lambda c: c.str.strip())
df.replace({"": np.nan, "Unknown": np.nan, "unspecified": np.nan}, inplace=True)

# ----- autofix helpers -----
def note_fix(row_idx, col, issue, old_val, new_val):
    errors.append({
        "row": int(row_idx),
        "column": col,
        "issue": f"autofix::{issue}",
        "value": old_val,
        "fixed_to": new_val,
    })

DAYMAP = {
    "mon":"Monday","monday":"Monday",
    "tue":"Tuesday","tues":"Tuesday","tuesday":"Tuesday",
    "wed":"Wednesday","weds":"Wednesday","wednesday":"Wednesday",
    "thu":"Thursday","thur":"Thursday","thurs":"Thursday","thursday":"Thursday",
    "fri":"Friday","friday":"Friday",
    "sat":"Saturday","saturday":"Saturday",
    "sun":"Sunday","sunday":"Sunday",
}
GENDERMAP = {"m":"Male","male":"Male","f":"Female","female":"Female"}

# === 45-column schema ===
schema = {
  # core ids
  "canonical_tx_id":"key","canonical_tx_id_norm":"str","canonical_tx_id_payload":"str",
  # time dims
  "transaction_date":"dt","year_number":"int","month_number":"int","month_name":"str",
  "quarter_number":"int","day_name":"str",
  "weekday_vs_weekend":{"enum":{"Weekday","Weekend","Unknown"}},
  "iso_week":"int",
  # facts
  "amount":"num","transaction_value":"num","basket_size":"int","was_substitution":"int",
  # location
  "store_id":"str","product_id":"str","barangay":"str",
  # demographics
  "age":"int","gender":{"enum":{"Male","Female","Unknown"}},
  "emotional_state":"str","facial_id":"str","role_id":"str",
  # personas
  "persona_id":"str","persona_confidence":"num",
  "persona_alternative_roles":"str","persona_rule_source":"str",
  # brand analytics
  "primary_brand":"str","secondary_brand":"str",
  "primary_brand_confidence":"num","all_brands_mentioned":"str",
  "brand_switching_indicator":{"enum":{"Single-Brand","Brand-Switch-Considered","No-Analytics-Data","Unknown"}},
  "transcription_text":"str","co_purchase_patterns":"str",
  # tech
  "device_id":"str","session_id":"str","interaction_id":"str",
  "data_source_type":{"enum":{"Enhanced-Analytics","Payload-Only"}},
  "payload_data_status":{"enum":{"JSON-Available","No-JSON"}},
  "payload_json_truncated":"str",
  "transaction_date_original":"dt","created_date":"dt",
  # derived
  "transaction_type":{"enum":{"Single-Item","Multi-Item"}},
  "time_of_day_category":{"enum":{"Morning","Afternoon","Evening","Night","Unknown"}},
  "customer_segment":"str",
}

errors=[];  mark=lambda i,c,iss,v: errors.append({"row":i,"column":c,"issue":iss,"value":v})

# type/enumeration enforcement
for col, rule in schema.items():
    if col not in df.columns: continue
    s=df[col]
    if rule in ("num","int"):
        coer=pd.to_numeric(s, errors="coerce", downcast="integer" if rule=="int" else None)
        bad = s.notna() & coer.isna()
        for i,v in s[bad].items(): mark(i,col,"type_coerce_fail",v)
        df[col]=coer
    elif rule=="dt":
        coer=pd.to_datetime(s, errors="coerce", utc=False, infer_datetime_format=True)
        bad = s.notna() & coer.isna()
        for i,v in s[bad].items(): mark(i,col,"date_parse_fail",v)
        df[col]=coer
    elif rule=="key":
        miss=s.isna()
        for i in s[miss].index: mark(i,col,"missing_key",np.nan)
    elif isinstance(rule,dict) and "enum" in rule:
        bad = s.notna() & ~s.isin(rule["enum"])
        for i,v in s[bad].items(): mark(i,col,"enum_violation",v)

# --------------------
# business rules (enhanced)
# --------------------
def flag(col, cond, name):
    if col in df.columns:
        bad = df[col].notna() & ~cond(df[col])
        for i, v in df.loc[bad, col].items():
            mark(i, col, name, v)

# existing basics
flag("amount",             lambda x: x >= 0,                 "amount_negative")
flag("transaction_value",  lambda x: x >= 0,                 "txn_value_negative")
flag("basket_size",        lambda x: x >= 1,                 "basket_size_min1")
flag("age",                lambda x: (x >= 10) & (x <= 100), "age_out_of_range")

# --- NEW: bounds & ranges ---
for col in ("primary_brand_confidence", "persona_confidence"):
    if col in df.columns:
        flag(col, lambda x: (x >= 0) & (x <= 1), f"{col}_out_of_[0,1]")

for col, lo, hi, issue in [
    ("month_number",   1, 12, "month_out_of_range"),
    ("quarter_number", 1,  4, "quarter_out_of_range"),
    ("iso_week",       1, 53, "iso_week_out_of_range"),
]:
    if col in df.columns:
        flag(col, lambda x, lo=lo, hi=hi: (x >= lo) & (x <= hi), issue)

# --- NEW: JSON availability consistency ---
if {"payload_data_status", "payload_json_truncated"} <= set(df.columns):
    mask_json_avail = df["payload_data_status"].eq("JSON-Available")
    bad = mask_json_avail & (df["payload_json_truncated"].isna() | (df["payload_json_truncated"].str.len() < 1))
    for i, _ in df[bad].iterrows():
        mark(i, "payload_json_truncated", "json_status_mismatch", None)

# --- NEW: brand switching logic consistency ---
def _has_multiple_brands(row):
    abm = row.get("all_brands_mentioned")
    pb  = row.get("primary_brand")
    sb  = row.get("secondary_brand")
    has_abm_multi = isinstance(abm, str) and ";" in abm
    has_two_named = (isinstance(pb, str) and isinstance(sb, str) and pb and sb and pb != sb)
    return has_abm_multi or has_two_named

need_switch = df.get("brand_switching_indicator")
if need_switch is not None:
    needs_multi = need_switch.eq("Brand-Switch-Considered")
    if "all_brands_mentioned" in df and "primary_brand" in df and "secondary_brand" in df:
        bad = needs_multi & ~df.apply(_has_multiple_brands, axis=1)
        for i, _ in df[bad].iterrows():
            mark(i, "brand_switching_indicator", "switch_flag_without_evidence", "expected>=2_brands")

# --- NEW: transaction_type vs basket_size sanity ---
if {"transaction_type", "basket_size"} <= set(df.columns):
    bad_single = df["transaction_type"].eq("Single-Item") & (df["basket_size"].fillna(1) > 1)
    for i, v in df.loc[bad_single, "basket_size"].items():
        mark(i, "transaction_type", "single_item_with_multi_basket", int(v))

# --- NEW: data_source_type consistency hints ---
if {"data_source_type", "interaction_id"} <= set(df.columns):
    bad_enh = df["data_source_type"].eq("Enhanced-Analytics") & df["interaction_id"].isna()
    for i, _ in df[bad_enh].iterrows():
        mark(i, "interaction_id", "enhanced_missing_interaction_id", None)

# keep existing "filled_by_amount_candidate" helper
if "transaction_value" in df and "amount" in df:
    miss = df["transaction_value"].isna() & df["amount"].notna()
    for i, v in df.loc[miss, "amount"].items():
        mark(i, "transaction_value", "filled_by_amount_candidate", v)

# de-dup by strong ids (keep first)
subset=[c for c in ["canonical_tx_id","session_id","interaction_id"] if c in df.columns]
if subset: df = df.drop_duplicates(subset=subset, keep="first")

# apply auto-fixes (logs go into errors with issue prefix 'autofix::')
def apply_autofixes(df):
    # Trim whitespace on all string cols
    for c in df.select_dtypes(include="object").columns:
        s = df[c]
        trimmed = s.where(s.isna(), s.astype(str).str.strip())
        changed = (trimmed != s) & s.notna()
        for i, (old, new) in df.loc[changed, c].assign(new=trimmed[changed]).rename(columns={c:"old"}).iterrows():
            note_fix(i, c, "trim_whitespace", old, new)
        df[c] = trimmed

    # 1) Coerce transaction_value ← amount when missing (soft fill)
    if {"transaction_value","amount"} <= set(df.columns):
        miss = df["transaction_value"].isna() & df["amount"].notna()
        for i, v in df.loc[miss, "amount"].items():
            note_fix(i, "transaction_value", "filled_from_amount", None, float(v))
        df.loc[miss, "transaction_value"] = df.loc[miss, "amount"]

    # 2) Clamp confidences into [0,1]
    for col in ("primary_brand_confidence","persona_confidence"):
        if col in df.columns:
            over = df[col].notna() & (df[col] > 1)
            under = df[col].notna() & (df[col] < 0)
            if over.any():
                for i, v in df.loc[over, col].items():
                    note_fix(i, col, "clamp_hi_1.0", float(v), 1.0)
            if under.any():
                for i, v in df.loc[under, col].items():
                    note_fix(i, col, "clamp_lo_0.0", float(v), 0.0)
            df.loc[over, col] = 1.0
            df.loc[under, col] = 0.0

    # 3) Normalize day_name + weekday_vs_weekend
    if "day_name" in df.columns:
        lower = df["day_name"].astype(str).str.lower()
        mapped = lower.map(DAYMAP).where(~lower.isna(), df["day_name"])
        changed = df["day_name"].ne(mapped) & df["day_name"].notna()
        for i, (o, n) in df.loc[changed, ["day_name"]].assign(new=mapped[changed]).rename(columns={"day_name":"old"}).iterrows():
            note_fix(i, "day_name", "normalize_day_name", o, n["new"])
        df.loc[changed, "day_name"] = mapped[changed]
    if {"day_name","weekday_vs_weekend"} <= set(df.columns):
        wmap = df["day_name"].map(lambda d: "Weekend" if d in ("Saturday","Sunday") else ("Weekday" if pd.notna(d) else None))
        need = df["weekday_vs_weekend"].ne(wmap) & wmap.notna()
        for i, n in df.loc[need, :].index.to_series().items():
            note_fix(i, "weekday_vs_weekend", "recompute_from_day_name", df.at[i,"weekday_vs_weekend"], wmap.at[i])
        df.loc[need, "weekday_vs_weekend"] = wmap[need]

    # 4) Recompute Y/M/Q/iso_week from transaction_date if missing or zero-ish
    if "transaction_date" in df.columns:
        dt = pd.to_datetime(df["transaction_date"], errors="coerce")
        if "year_number" in df.columns:
            miss = df["year_number"].isin([0, None]) | df["year_number"].isna()
            df.loc[miss & dt.notna(), "year_number"] = dt.dt.year
        if "month_number" in df.columns:
            miss = df["month_number"].isin([0, None]) | df["month_number"].isna()
            df.loc[miss & dt.notna(), "month_number"] = dt.dt.month
        if "month_name" in df.columns:
            miss = df["month_name"].isin(["", "Unknown", None]) | df["month_name"].isna()
            df.loc[miss & dt.notna(), "month_name"] = dt.dt.month_name()
        if "quarter_number" in df.columns:
            miss = df["quarter_number"].isin([0, None]) | df["quarter_number"].isna()
            df.loc[miss & dt.notna(), "quarter_number"] = dt.dt.quarter
        if "iso_week" in df.columns:
            miss = df["iso_week"].isin([0, None]) | df["iso_week"].isna()
            df.loc[miss & dt.notna(), "iso_week"] = dt.dt.isocalendar().week.astype(int)

        # 5) Recompute time_of_day_category if missing
        if "time_of_day_category" in df.columns:
            h = dt.dt.hour
            tod = pd.Series(np.select(
                [h.between(6,11), h.between(12,17), h.between(18,21)],
                ["Morning","Afternoon","Evening"],
                default="Night"
            ), index=df.index)
            miss = df["time_of_day_category"].isna() | (df["time_of_day_category"] == "Unknown")
            df.loc[miss & dt.notna(), "time_of_day_category"] = tod[miss & dt.notna()]

    # 6) Standardize gender
    if "gender" in df.columns:
        g = df["gender"].astype(str).str.strip().str.lower()
        mapped = g.map(GENDERMAP).fillna(df["gender"])
        changed = df["gender"].ne(mapped)
        for i, (o, n) in df.loc[changed, ["gender"]].assign(new=mapped[changed]).rename(columns={"gender":"old"}).iterrows():
            note_fix(i, "gender", "normalize_gender", o, n["new"])
        df.loc[changed, "gender"] = mapped

    # 7) Age clamp into 10..100 (edge values kept, outliers set NA so rule can flag)
    if "age" in df.columns:
        bad = df["age"].notna() & ~df["age"].between(10, 100)
        for i, v in df.loc[bad, "age"].items():
            note_fix(i, "age", "out_of_range_to_null", int(v), None)
        df.loc[bad, "age"] = pd.NA

    # 8) Basket size minimum = 1 (coerce null/zero to 1)
    if "basket_size" in df.columns:
        bad = df["basket_size"].isna() | (df["basket_size"] < 1)
        for i, v in df.loc[bad, "basket_size"].items():
            note_fix(i, "basket_size", "min1_coerce", v, 1)
        df.loc[bad, "basket_size"] = 1

    # 9) Brand switching indicator recomputation when evidence contradicts
    needed_cols = {"brand_switching_indicator","all_brands_mentioned","primary_brand","secondary_brand"}
    if needed_cols <= set(df.columns):
        def needs_switch(row):
            abm = row["all_brands_mentioned"]
            pb, sb = row["primary_brand"], row["secondary_brand"]
            has_multi = isinstance(abm, str) and ";" in abm
            two_named = isinstance(pb, str) and isinstance(sb, str) and pb and sb and pb != sb
            return "Brand-Switch-Considered" if (has_multi or two_named) else "Single-Brand"
        recomputed = df.apply(needs_switch, axis=1)
        conflict = df["brand_switching_indicator"].ne(recomputed) & recomputed.notna()
        for i, newv in recomputed[conflict].items():
            note_fix(i, "brand_switching_indicator", "recomputed_from_evidence", df.at[i,"brand_switching_indicator"], newv)
        df.loc[conflict, "brand_switching_indicator"] = recomputed[conflict]

    # 10) JSON status clean-up
    if {"payload_data_status","payload_json_truncated"} <= set(df.columns):
        missing_body = df["payload_json_truncated"].isna() | (df["payload_json_truncated"].astype(str).str.len() == 0)
        flip = df["payload_data_status"].eq("JSON-Available") & missing_body
        for i, _ in df[flip].iterrows():
            note_fix(i, "payload_data_status", "status_set_to_No-JSON", "JSON-Available", "No-JSON")
        df.loc[flip, "payload_data_status"] = "No-JSON"

    return df

df = apply_autofixes(df)

# drop rows failing hard rules
hard={"missing_key","type_coerce_fail","date_parse_fail"}
drop_idx = sorted({e["row"] for e in errors if e["issue"] in hard})
clean = df.drop(index=drop_idx)

pd.DataFrame(errors).to_csv(elog, index=False)
clean.to_csv(outp, index=False)

# Calculate statistics
autofix_count = len([e for e in errors if e["issue"].startswith("autofix::")])
validation_errors = len([e for e in errors if not e["issue"].startswith("autofix::")])

print(json.dumps({
  "input_rows": int(len(df)+len(drop_idx)),
  "clean_rows": int(len(clean)),
  "dropped_rows": int(len(drop_idx)),
  "errors_logged": int(len(errors)),
  "autofixes_applied": autofix_count,
  "validation_errors": validation_errors,
  "data_quality_score": round((1 - validation_errors / max(len(clean), 1)) * 100, 2)
}))