# Edge-Only STT + Facial Inference System

**Privacy-First Analytics**: No audio or images leave the device. Only JSON payloads with processed data.

## 🔒 Security & Privacy Guarantees

- **No raw audio leaves the Pi** - Audio files are deleted immediately after transcription
- **No images leave the Pi** - Only face counts and bounding boxes are transmitted
- **HMAC-SHA256 signed payloads** - Prevents tampering and ensures authenticity
- **Single JSONB transaction per event** - Clean, auditable data model
- **On-device STT with faster-whisper** - Local speech-to-text processing
- **On-device face detection with OpenCV** - Local facial inference

## 📋 System Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌────────────────┐
│   Raspberry Pi  │  HTTPS  │   Edge TX API    │   SQL   │   Supabase DB  │
│  ┌───────────┐  │  JSON   │  (HMAC verify)   │ INSERT  │ ┌────────────┐ │
│  │Audio→STT  │  │ ------> │  /api/edge-tx    │ ------> │ │edge_trans- │ │
│  │Image→Face │  │  HMAC   │                  │         │ │actions     │ │
│  └───────────┘  │         │                  │         │ └────────────┘ │
│  Delete files!  │         │                  │         │   Silver/Gold  │
└─────────────────┘         └──────────────────┘         └────────────────┘
```

## 🚀 Quick Start

### 1. Server Setup

```bash
# Set environment variables
export EDGE_HMAC_SECRET="your-very-long-random-secret-key"
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
export SUPABASE_PROJECT_ID="your-project-id"

# Apply database schema
psql "$SUPABASE_DB_URL" -f sql/agentdash_edge_only.sql

# Deploy edge function (optional)
supabase functions deploy edge-refresh --project-ref "$SUPABASE_PROJECT_ID"

# Start Next.js server
cd apps/agentdash
npm install
npm run dev
```

### 2. Device Setup (Raspberry Pi)

```bash
# Install dependencies
python3 -m venv venv
source venv/bin/activate
pip install faster-whisper opencv-python sounddevice numpy requests

# Set environment variables
export EDGE_URL="https://your-app.vercel.app/api/edge-tx"
export EDGE_HMAC_SECRET="your-very-long-random-secret-key"
export DEVICE_ID="pi-aisle-03"
export STORE_ID="STORE-001"
export CAMERA_ID="cam-01"
export LANG="fil"  # Filipino/Tagalog

# Run edge script
python device/edge_tx.py
```

## 📊 JSON Payload Schema

Each transaction contains:

```json
{
  "schema_version": 1,
  "tx_id": "uuid",
  "device_id": "pi-aisle-03",
  "ts": "2025-08-18T03:05:14.231Z",
  "stt": {
    "text": "pabili po Palmolive shampoo",
    "lang": "fil",
    "confidence": 0.92,
    "words": [
      {"w": "pabili", "s": 0.10, "e": 0.35},
      {"w": "po", "s": 0.35, "e": 0.42},
      {"w": "Palmolive", "s": 0.50, "e": 0.90},
      {"w": "shampoo", "s": 0.92, "e": 1.40}
    ],
    "brands": [
      {"brand": "Palmolive", "offset_s": 0.50, "confidence": 0.90}
    ],
    "request_type": "branded"
  },
  "vision": {
    "face_count": 1,
    "faces": [
      {
        "bbox": [312, 140, 96, 96],
        "age_band": "18-24",
        "gender": "F",
        "expression": "neutral"
      }
    ]
  },
  "context": {
    "store_id": "STORE-001",
    "camera_id": "cam-01",
    "geo": {"lat": 14.5547, "lon": 121.0244}
  }
}
```

## 🔧 Configuration

### Environment Variables

**Server (Next.js)**:
```env
EDGE_HMAC_SECRET=your-secret-key
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_SERVICE_ROLE_KEY=xxx
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
```

**Device (Raspberry Pi)**:
```env
EDGE_URL=https://your-app/api/edge-tx
EDGE_HMAC_SECRET=your-secret-key
DEVICE_ID=pi-aisle-03
STORE_ID=STORE-001
CAMERA_ID=cam-01
LANG=fil
REC_SECONDS=2.5
WHISPER_MODEL=base
GEO_LAT=14.5547
GEO_LON=121.0244
```

### Whisper Model Options
- `tiny` - Fastest, lowest accuracy
- `base` - Recommended for Pi (good balance)
- `small` - Better accuracy, slower
- `medium` - High accuracy, requires more RAM

## 📈 Analytics Views

The system provides several materialized views:

- `scout.gold_brand_mentions_daily` - Daily brand mention counts
- `scout.gold_footfall_daily` - Daily footfall by device
- `scout.edge_analytics_summary` - Hourly transaction summaries
- `scout.request_type_distribution` - Branded vs unbranded requests
- `scout.demographics_summary` - Age/gender distribution

## 🛠️ Maintenance

### Refresh Materialized Views
```sql
SELECT scout.refresh_edge_gold();
```

### Monitor Edge Transactions
```sql
-- Recent transactions
SELECT * FROM scout.edge_transactions 
ORDER BY created_at DESC LIMIT 10;

-- Device status
SELECT device_id, COUNT(*) as tx_count, MAX(ts) as last_seen
FROM scout.edge_transactions
WHERE ts > NOW() - INTERVAL '1 hour'
GROUP BY device_id;
```

### Verify HMAC Signatures
```sql
-- Check signature validity (requires scout.edge_hmac_secret GUC)
SELECT id, device_id, ts, 
       scout.verify_edge_sig(payload, sig) as valid
FROM scout.edge_transactions
ORDER BY created_at DESC LIMIT 10;
```

## 🚨 Troubleshooting

### Common Issues

1. **HMAC verification fails**
   - Ensure `EDGE_HMAC_SECRET` matches on device and server
   - Check for clock drift between device and server

2. **No audio detected**
   - Verify microphone permissions: `arecord -l`
   - Test recording: `arecord -d 3 test.wav && aplay test.wav`

3. **Face detection not working**
   - Check camera: `raspistill -o test.jpg`
   - Verify OpenCV installation: `python -c "import cv2; print(cv2.__version__)"`

4. **Whisper model errors**
   - Reduce model size if RAM limited
   - Use `compute_type="int8"` for efficiency

### Debug Mode
```bash
# Enable verbose logging
export DEBUG=1
python device/edge_tx.py
```

## 📐 Scaling Considerations

- **Multiple devices**: Use unique `DEVICE_ID` for each Pi
- **Load balancing**: Deploy multiple API instances
- **Batch processing**: Schedule `refresh_edge_gold()` via cron
- **Data retention**: Partition `edge_transactions` by month

## 🔐 Security Best Practices

1. **Rotate HMAC secrets** regularly (monthly)
2. **Use HTTPS only** for edge URLs
3. **Implement rate limiting** on `/api/edge-tx`
4. **Monitor for anomalies** in transaction patterns
5. **Audit trail**: All transactions are immutable

---

Built for TBWA Enterprise - Privacy-First Edge Analytics