# ZIP Upload Integration Guide

## Overview

The Scout Dashboard now supports ZIP file uploads for bulk data ingestion. Users can upload ZIP files containing campaign data in CSV, Excel, or JSON format, which will be automatically extracted, validated, and processed.

## Features

### 🚀 Core Capabilities
- **Multi-file ZIP support**: Upload multiple data files in a single ZIP
- **Format support**: CSV, Excel (.xlsx, .xls), JSON, TSV
- **Auto-detection**: Automatically detects data type (campaigns, metrics, etc.)
- **Validation**: Comprehensive security and data validation
- **Progress tracking**: Real-time upload and processing status
- **Duplicate detection**: Prevents re-uploading identical files

### 🔐 Security Features
- File size limits (100MB per ZIP)
- File type validation
- Malware scanning
- Path traversal protection
- SQL injection prevention
- Rate limiting (10 uploads per 15 minutes)

## API Endpoints

### Upload File
```http
POST /api/v5/upload
Authorization: Bearer <token>
Content-Type: multipart/form-data

FormData:
- file: <zip file>
- source: "manual" | "api" | "dashboard"
- description: "Optional description"
- tags: ["tag1", "tag2"]
- processImmediately: true | false
```

### Check Upload Status
```http
GET /api/v5/upload/:id/status
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "id": "upload-id",
    "filename": "data.zip",
    "status": "completed",
    "extractedFileCount": 5
  }
}
```

### List Uploads
```http
GET /api/v5/uploads?page=1&limit=20&status=completed
Authorization: Bearer <token>
```

### Delete Upload
```http
DELETE /api/v5/upload/:id
Authorization: Bearer <token>
```

## Frontend Integration

### Using the ZipUpload Component

```tsx
import { ZipUpload } from '@/components/ZipUpload';

function MyPage() {
  const handleUploadComplete = (uploadId: string) => {
    console.log('Upload completed:', uploadId);
    // Refresh data or show success message
  };

  return (
    <ZipUpload 
      onUploadComplete={handleUploadComplete}
      source="dashboard"
      className="my-4"
    />
  );
}
```

### Full Data Import Page
The complete data import page is available at `/data-import` and includes:
- Upload interface
- Upload history
- Processing statistics
- File management

## Database Schema

### Tables Created
- `scout_dash.file_uploads` - Main upload tracking
- `scout_dash.extracted_files` - Individual files from ZIPs
- `scout_dash.imported_campaigns` - Processed campaign data
- `scout_dash.imported_metrics` - Processed metrics data
- `scout_dash.imported_generic_data` - Unrecognized data for review
- `scout_dash.processing_log` - Audit trail

### Row Level Security
All tables have RLS enabled - users can only see their own uploads.

## Data Processing Flow

1. **Upload**: File uploaded to server
2. **Validation**: Security checks and file validation
3. **Extraction**: ZIP contents extracted
4. **Analysis**: Data structure detected
5. **Processing**: Data transformed and stored
6. **Completion**: Status updated, user notified

## Supported Data Formats

### Campaign Data CSV Example
```csv
campaign_name,brand,start_date,end_date,budget,impressions,clicks,conversions
Summer Sale 2024,Brand A,2024-06-01,2024-08-31,50000,1500000,75000,3000
Back to School,Brand B,2024-08-15,2024-09-15,30000,900000,45000,1800
```

### Metrics Data JSON Example
```json
[
  {
    "date": "2024-01-01",
    "campaign": "Winter Campaign",
    "impressions": 50000,
    "clicks": 2500,
    "conversions": 100
  }
]
```

### Excel Format
- First row should contain column headers
- Supported columns: campaign_name, brand, start_date, end_date, budget, metrics
- Multiple sheets will be processed separately

## Error Handling

### Common Errors
- `FILE_TOO_LARGE`: File exceeds 100MB limit
- `INVALID_FILE_TYPE`: Non-ZIP file uploaded
- `DUPLICATE_FILE`: File already uploaded
- `INVALID_ZIP_CONTENTS`: ZIP contains invalid files
- `SUSPICIOUS_CONTENT`: Security check failed

### Error Response Format
```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  }
}
```

## Implementation Checklist

### Backend Setup
- [x] Install dependencies: `npm install multer adm-zip csv-parse xlsx`
- [x] Create upload routes
- [x] Implement ZIP processor
- [x] Add validation middleware
- [x] Create database schema
- [x] Configure authentication

### Frontend Setup
- [x] Install dependencies: `npm install react-dropzone lucide-react sonner`
- [x] Add ZipUpload component
- [x] Create DataImport page
- [x] Add route to navigation
- [x] Configure upload endpoint

### Database Setup
- [ ] Run migration: `supabase migration up`
- [ ] Verify RLS policies
- [ ] Test user permissions

## Testing

### Manual Testing
1. Upload a valid ZIP with CSV files
2. Upload a ZIP with mixed file types
3. Upload an invalid file (non-ZIP)
4. Upload a file exceeding size limit
5. Upload duplicate files
6. Test concurrent uploads

### Automated Tests
```typescript
// Example test for upload endpoint
describe('Upload API', () => {
  it('should accept valid ZIP files', async () => {
    const formData = new FormData();
    formData.append('file', validZipFile);
    formData.append('source', 'test');
    
    const response = await request(app)
      .post('/api/v5/upload')
      .set('Authorization', `Bearer ${token}`)
      .attach('file', 'test-data.zip');
      
    expect(response.status).toBe(200);
    expect(response.body.success).toBe(true);
  });
});
```

## Performance Considerations

- Large files are processed asynchronously
- Extraction happens in background jobs
- Database inserts are batched
- Progress tracked in real-time
- Clean up old uploads periodically

## Security Best Practices

1. Always validate file types
2. Scan for malicious content
3. Use rate limiting
4. Implement proper authentication
5. Monitor upload patterns
6. Regular security audits

## Next Steps

1. **Deploy Changes**
   ```bash
   # Run database migration
   supabase db push
   
   # Deploy application
   npm run deploy
   ```

2. **Configure Environment**
   ```env
   # Add to .env
   MAX_UPLOAD_SIZE=104857600
   UPLOAD_RATE_LIMIT=10
   ```

3. **Add Navigation**
   Add link to Data Import page in your navigation menu

4. **Monitor Usage**
   - Track upload success rates
   - Monitor processing times
   - Review error logs
   - Optimize based on usage patterns