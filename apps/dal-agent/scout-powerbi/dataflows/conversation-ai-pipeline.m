// Scout Conversation AI Pipeline - Dataflow Gen2 M Query
// Extracts conversation text from transactions and enriches with Azure Cognitive Services Text Analytics
// Processes sentiment analysis, key phrase extraction, and language detection

let
    // Source: Transaction data from Fabric Warehouse
    Source = AzureSqlDatabase.Database("SQL-TBWA-ProjectScout-Reporting-Prod.sql.azuresynapse.net", "SQL-TBWA-ProjectScout-Reporting-Prod"),

    // Get transactions with conversation text that haven't been processed yet
    TransactionQuery = "
        SELECT DISTINCT
            tx.TransactionID as canonical_tx_id,
            tx.InteractionID as interaction_id,
            COALESCE(tx.ConversationText, tx.CustomerFeedback, tx.Notes, 'No conversation text available') as original_text
        FROM mart_tx tx
        LEFT JOIN silver.conversation_ai ai ON tx.TransactionID = ai.canonical_tx_id
        WHERE tx.TransactionDate >= DATEADD(DAY, -7, GETDATE())  -- Last 7 days only
            AND ai.canonical_tx_id IS NULL  -- Not yet processed
            AND (
                tx.ConversationText IS NOT NULL
                OR tx.CustomerFeedback IS NOT NULL
                OR tx.Notes IS NOT NULL
            )
            AND LEN(COALESCE(tx.ConversationText, tx.CustomerFeedback, tx.Notes, '')) > 10  -- Minimum text length
        ORDER BY tx.TransactionID
    ",

    SourceData = Value.NativeQuery(Source, TransactionQuery),

    // Filter out rows with empty or very short text
    FilteredData = Table.SelectRows(SourceData, each Text.Length([original_text]) > 10),

    // Add batch processing for API efficiency (process in groups of 10)
    AddedIndex = Table.AddIndexColumn(FilteredData, "Index", 0, 1, Int64.Type),
    AddedBatch = Table.AddColumn(AddedIndex, "BatchNumber", each Number.IntegerDivide([Index], 10), Int64.Type),

    // Group by batch for processing
    GroupedBatches = Table.Group(AddedBatch, {"BatchNumber"}, {
        {"BatchData", each _, type table}
    }),

    // Text Analytics Configuration
    TextAnalyticsKey = Environment.Variable("COGNITIVE_SERVICES_KEY"),
    TextAnalyticsEndpoint = Environment.Variable("COGNITIVE_SERVICES_ENDPOINT"),

    // Function to call Azure Text Analytics API
    CallTextAnalytics = (textData as table) as table =>
        let
            // Prepare documents for API call
            Documents = Table.TransformColumns(textData, {
                {"canonical_tx_id", Text.From, type text},
                {"original_text", each Text.Start(_, 5120), type text}  // Limit to API max length
            }),

            // Create API request body
            DocumentList = Table.ToRecords(Table.SelectColumns(Documents, {"canonical_tx_id", "original_text"})),
            RequestBody = [
                kind = "SentimentAnalysis,KeyPhraseExtraction,LanguageDetection",
                parameters = [],
                analysisInput = [
                    documents = List.Transform(DocumentList, each [
                        id = [canonical_tx_id],
                        text = [original_text],
                        language = "auto"
                    ])
                ]
            ],

            // Make API call
            ApiUrl = TextAnalyticsEndpoint & "/text/analytics/v3.1/analyze",
            Headers = [
                #"Ocp-Apim-Subscription-Key" = TextAnalyticsKey,
                #"Content-Type" = "application/json"
            ],

            Response = try Web.Contents(
                ApiUrl,
                [
                    Headers = Headers,
                    Content = Json.FromValue(RequestBody),
                    Timeout = #duration(0, 0, 2, 0)  // 2 minute timeout
                ]
            ) otherwise null,

            // Parse response if successful
            ParsedResponse = if Response <> null then
                let
                    JsonResponse = Json.Document(Response),

                    // Extract sentiment analysis results
                    SentimentResults = try JsonResponse[results][documents] otherwise {},
                    SentimentTable = if List.Count(SentimentResults) > 0 then
                        Table.FromRecords(List.Transform(SentimentResults, each [
                            canonical_tx_id = [id],
                            sentiment = [sentiment],
                            sentiment_pos = [confidenceScores][positive],
                            sentiment_neu = [confidenceScores][neutral],
                            sentiment_neg = [confidenceScores][negative]
                        ]))
                    else
                        #table({"canonical_tx_id", "sentiment", "sentiment_pos", "sentiment_neu", "sentiment_neg"}, {}),

                    // Extract key phrase results
                    KeyPhraseResults = try JsonResponse[results][documents] otherwise {},
                    KeyPhraseTable = if List.Count(KeyPhraseResults) > 0 then
                        Table.FromRecords(List.Transform(KeyPhraseResults, each [
                            canonical_tx_id = [id],
                            key_phrases = Text.Combine([keyPhrases], "; ")
                        ]))
                    else
                        #table({"canonical_tx_id", "key_phrases"}, {}),

                    // Extract language detection results
                    LanguageResults = try JsonResponse[results][documents] otherwise {},
                    LanguageTable = if List.Count(LanguageResults) > 0 then
                        Table.FromRecords(List.Transform(LanguageResults, each [
                            canonical_tx_id = [id],
                            language = [detectedLanguage][iso6391Name],
                            language_confidence = [detectedLanguage][confidenceScore]
                        ]))
                    else
                        #table({"canonical_tx_id", "language", "language_confidence"}, {}),

                    // Combine all results
                    CombinedResults =
                        let
                            Step1 = Table.NestedJoin(Documents, {"canonical_tx_id"}, SentimentTable, {"canonical_tx_id"}, "Sentiment", JoinKind.LeftOuter),
                            Step2 = Table.ExpandTableColumn(Step1, "Sentiment", {"sentiment", "sentiment_pos", "sentiment_neu", "sentiment_neg"}),
                            Step3 = Table.NestedJoin(Step2, {"canonical_tx_id"}, KeyPhraseTable, {"canonical_tx_id"}, "KeyPhrases", JoinKind.LeftOuter),
                            Step4 = Table.ExpandTableColumn(Step3, "KeyPhrases", {"key_phrases"}),
                            Step5 = Table.NestedJoin(Step4, {"canonical_tx_id"}, LanguageTable, {"canonical_tx_id"}, "Language", JoinKind.LeftOuter),
                            Step6 = Table.ExpandTableColumn(Step5, "Language", {"language", "language_confidence"})
                        in
                            Step6
                in
                    CombinedResults
            else
                // Return original data with null values if API call failed
                Table.AddColumn(Documents, "sentiment", each null, type text),

            // Add processing metadata
            FinalResult = Table.AddColumn(
                Table.AddColumn(
                    Table.AddColumn(
                        ParsedResponse,
                        "processing_timestamp",
                        each DateTimeZone.UtcNow(),
                        type datetimezone
                    ),
                    "processing_version",
                    each "TextAnalytics-v3.1",
                    type text
                ),
                "processing_status",
                each if Response <> null then "completed" else "failed",
                type text
            )
        in
            FinalResult,

    // Apply Text Analytics to each batch
    ProcessedBatches = Table.AddColumn(GroupedBatches, "ProcessedData", each CallTextAnalytics([BatchData]), type table),

    // Combine all processed batches
    CombinedResults = Table.Combine(ProcessedBatches[ProcessedData]),

    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(
        Table.AddColumn(
            Table.AddColumn(
                CombinedResults,
                "text_length",
                each Text.Length([original_text]),
                Int64.Type
            ),
            "word_count",
            each List.Count(Text.Split(Text.Clean([original_text]), " ")),
            Int64.Type
        ),
        "key_phrases_count",
        each if [key_phrases] <> null then List.Count(Text.Split([key_phrases], ";")) else 0,
        Int64.Type
    ),

    // Clean up and type the final data
    CleanedData = Table.TransformColumnTypes(AddCalculatedColumns, {
        {"canonical_tx_id", type text},
        {"interaction_id", type text},
        {"sentiment", type text},
        {"sentiment_pos", type number},
        {"sentiment_neu", type number},
        {"sentiment_neg", type number},
        {"key_phrases", type text},
        {"language", type text},
        {"language_confidence", type number},
        {"original_text", type text},
        {"text_length", Int64.Type},
        {"word_count", Int64.Type},
        {"key_phrases_count", Int64.Type},
        {"processing_timestamp", type datetimezone},
        {"processing_version", type text},
        {"processing_status", type text}
    }),

    // Add error handling column
    FinalData = Table.AddColumn(CleanedData, "error_message", each null, type text),

    // Add audit fields
    AuditedData = Table.AddColumn(
        Table.AddColumn(
            FinalData,
            "created_date",
            each DateTimeZone.UtcNow(),
            type datetimezone
        ),
        "modified_date",
        each DateTimeZone.UtcNow(),
        type datetimezone
    ),

    // Final column selection and ordering
    FinalResult = Table.SelectColumns(AuditedData, {
        "canonical_tx_id",
        "interaction_id",
        "sentiment",
        "sentiment_pos",
        "sentiment_neu",
        "sentiment_neg",
        "key_phrases",
        "language",
        "language_confidence",
        "original_text",
        "text_length",
        "word_count",
        "key_phrases_count",
        "processing_timestamp",
        "processing_version",
        "processing_status",
        "error_message",
        "created_date",
        "modified_date"
    })

in
    FinalResult