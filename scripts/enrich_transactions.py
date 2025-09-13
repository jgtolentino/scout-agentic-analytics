import pyodbc
import pandas as pd
import json

# DB connection config
conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=sqltbwaprojectscoutserver.database.windows.net;'
    'DATABASE=SQL-TBWA-ProjectScout-Reporting-Prod;'
    'UID=TBWA;'
    'PWD=R%40nd0mPA%24%242025%21'
)
cursor = conn.cursor()

# Load only unprocessed transactions
df = pd.read_sql("""
    SELECT TransactionID, TransactionTranscription
    FROM Sample.StoryTellingTransactions
    WHERE BrandName IS NULL
""", conn)

# Simulated enrichment function — replace with Claude API integration
def enrich_transcription(text):
    return {
        "BrandName": "Jollibee",
        "BrandContext": "bought Jollibee ChickenJoy",
        "SentimentScore": 0.87,
        "IsPrimaryBrand": 1,
        "BrandCategory": "F&B",
        "TriggerPhrase": "TikTok made me buy it",
        "NeedState": "craving",
        "BasketItems": "ChickenJoy, Coke",
        "TransactionTags": json.dumps({"promo": True, "emotion": "happy"})
    }

# Enrich and update back to SQL
for _, row in df.iterrows():
    enriched = enrich_transcription(row['TransactionTranscription'])
    cursor.execute("""
        UPDATE Sample.StoryTellingTransactions
        SET BrandName = ?, BrandContext = ?, SentimentScore = ?, IsPrimaryBrand = ?,
            BrandCategory = ?, TriggerPhrase = ?, NeedState = ?, BasketItems = ?, TransactionTags = ?
        WHERE TransactionID = ?
    """, (
        enriched["BrandName"],
        enriched["BrandContext"],
        enriched["SentimentScore"],
        enriched["IsPrimaryBrand"],
        enriched["BrandCategory"],
        enriched["TriggerPhrase"],
        enriched["NeedState"],
        enriched["BasketItems"],
        enriched["TransactionTags"],
        row["TransactionID"]
    ))

conn.commit()
cursor.close()
conn.close()