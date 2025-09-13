// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import JSZip from "https://esm.sh/jszip@3.10.1";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GMAIL_API_KEY = Deno.env.get("GMAIL_API_KEY");

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, { db: { schema: "scout" } });

interface EmailAttachment {
  id: string;
  sender_email: string;
  filename: string;
  file_size: number;
  mime_type: string;
  gmail_message_id: string;
  gmail_attachment_id: string;
  processing_status: string;
}

async function downloadGmailAttachment(messageId: string, attachmentId: string): Promise<Uint8Array> {
  // This would integrate with Gmail API to download attachments
  // For now, returning placeholder
  throw new Error("Gmail API integration required");
}

async function processZipFile(attachment: EmailAttachment, zipData: Uint8Array) {
  const zip = await JSZip.loadAsync(zipData);
  const records: any[] = [];
  let processedCount = 0;
  let errorCount = 0;

  // Upload ZIP to S3 bucket first
  const s3Path = `email-attachments/${attachment.sender_email}/${attachment.filename}`;
  const { error: uploadError } = await supabase.storage
    .from("scout-ingest")
    .upload(s3Path, zipData, {
      contentType: attachment.mime_type,
      upsert: true
    });

  if (uploadError) throw uploadError;

  // Process each JSON file in the ZIP
  for (const [entryName, file] of Object.entries(zip.files)) {
    if (file.dir || !entryName.toLowerCase().endsWith(".json")) continue;
    
    try {
      const text = await file.async("string");
      const data = JSON.parse(text);
      
      // Map to bronze schema
      records.push({
        source_type: "email_attachment",
        source_file: s3Path,
        entry_name: entryName,
        sender_email: attachment.sender_email,
        device_id: data.device_id || data.store_id || "unknown",
        transaction_id: data.transaction_id || data.id || null,
        captured_at: data.timestamp || data.captured_at || new Date().toISOString(),
        payload: data,
        ingested_at: new Date().toISOString()
      });
      
      processedCount++;
    } catch (e) {
      console.error(`Error processing ${entryName}:`, e);
      errorCount++;
    }

    // Batch insert every 500 records
    if (records.length >= 500) {
      await insertBronzeRecords(records);
      records.length = 0;
    }
  }

  // Final insert
  if (records.length > 0) {
    await insertBronzeRecords(records);
  }

  // Update attachment status
  await supabase
    .from("email_attachments")
    .update({
      processing_status: "completed",
      processed_at: new Date().toISOString(),
      s3_path: s3Path,
      records_processed: processedCount,
      records_failed: errorCount
    })
    .eq("id", attachment.id);

  // Trigger Bronze → Silver → Gold transformation
  await supabase.rpc("transform_email_bronze_to_silver");
  
  return { processedCount, errorCount };
}

async function insertBronzeRecords(records: any[]) {
  const { error } = await supabase
    .from("bronze_email_transactions")
    .upsert(records, {
      onConflict: "source_file,entry_name",
      ignoreDuplicates: true
    });
  
  if (error) throw error;
}

Deno.serve(async (req) => {
  try {
    // Get pending email attachments
    const { data: attachments, error } = await supabase
      .from("email_attachments")
      .select("*")
      .eq("processing_status", "pending")
      .in("mime_type", ["application/zip", "application/x-zip-compressed"])
      .order("received_at", { ascending: true })
      .limit(10);

    if (error) throw error;
    if (!attachments || attachments.length === 0) {
      return new Response(JSON.stringify({ message: "No pending attachments" }), { 
        status: 200,
        headers: { "Content-Type": "application/json" }
      });
    }

    const results = [];
    
    for (const attachment of attachments) {
      try {
        console.log(`Processing attachment: ${attachment.filename} from ${attachment.sender_email}`);
        
        // Update status to processing
        await supabase
          .from("email_attachments")
          .update({ processing_status: "processing" })
          .eq("id", attachment.id);

        // For Eugene Valencia's files, we'll use the direct S3 upload path
        // since Gmail API integration is not yet configured
        if (attachment.sender_email === "eugene.valencia@tbwa.com") {
          // These files should be manually uploaded to scout-ingest/email-attachments/eugene/
          const s3Path = `email-attachments/eugene/${attachment.filename}`;
          
          // Check if file exists in S3
          const { data: fileData, error: downloadError } = await supabase.storage
            .from("scout-ingest")
            .download(s3Path);
          
          if (downloadError) {
            throw new Error(`File not found in S3: ${s3Path}. Please upload manually.`);
          }
          
          const zipData = new Uint8Array(await fileData.arrayBuffer());
          const result = await processZipFile(attachment, zipData);
          results.push({ attachment: attachment.filename, ...result });
        } else {
          // Future: Gmail API integration
          throw new Error("Gmail API integration not configured");
        }
        
      } catch (e) {
        console.error(`Failed to process ${attachment.filename}:`, e);
        
        // Mark as failed
        await supabase
          .from("email_attachments")
          .update({
            processing_status: "failed",
            error_message: String(e)
          })
          .eq("id", attachment.id);
          
        results.push({ 
          attachment: attachment.filename, 
          error: String(e) 
        });
      }
    }

    return new Response(JSON.stringify({ 
      processed: results.length,
      results 
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
    
  } catch (e) {
    console.error("Function error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    });
  }
});