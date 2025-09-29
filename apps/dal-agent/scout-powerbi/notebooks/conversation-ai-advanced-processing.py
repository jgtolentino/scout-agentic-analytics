# Databricks notebook source
# MAGIC %md
# MAGIC # Scout Conversation AI - Advanced Processing
# MAGIC
# MAGIC **Purpose**: Advanced text processing for conversation analytics using PySpark and ML libraries
# MAGIC
# MAGIC **Features**:
# MAGIC - Advanced key phrase extraction and clustering
# MAGIC - Topic modeling and theme identification
# MAGIC - Sentiment analysis enhancement
# MAGIC - Text similarity and customer journey analysis
# MAGIC - Philippine language processing (Tagalog, Cebuano)
# MAGIC
# MAGIC **Architecture**: Reads from Silver layer, enriches with ML insights, writes to Platinum layer

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup and Configuration

# COMMAND ----------

# Import required libraries
import pyspark.sql.functions as F
from pyspark.sql.types import *
from pyspark.sql import SparkSession
from pyspark.ml.feature import StopWordsRemover, Tokenizer, CountVectorizer, IDF
from pyspark.ml.clustering import LDA
from pyspark.ml import Pipeline
from pyspark.ml.evaluation import ClusteringEvaluator

import pandas as pd
import numpy as np
import re
from collections import Counter
from datetime import datetime, timedelta
import json

# Text processing libraries
import nltk
from nltk.corpus import stopwords
from nltk.stem import PorterStemmer
from nltk.tokenize import word_tokenize

# Download NLTK data if needed
try:
    nltk.data.find('tokenizers/punkt')
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('punkt')
    nltk.download('stopwords')

print("✅ Libraries imported successfully")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Source Configuration

# COMMAND ----------

# Fabric Warehouse connection configuration
warehouse_name = "SQL-TBWA-ProjectScout-Reporting-Prod"
server_name = f"{warehouse_name}.sql.azuresynapse.net"

# Connection string for Fabric Warehouse
jdbc_url = f"jdbc:sqlserver://{server_name}:1433;database={warehouse_name};encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.sql.azuresynapse.net;loginTimeout=30;"

# Read conversation AI data from Silver layer
conversation_df = spark.read \
    .format("jdbc") \
    .option("url", jdbc_url) \
    .option("dbtable", "silver.conversation_ai") \
    .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
    .load()

# Read transaction context for business intelligence
transaction_context_df = spark.read \
    .format("jdbc") \
    .option("url", jdbc_url) \
    .option("dbtable", "gold.v_conversation_insights") \
    .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
    .load()

print(f"✅ Loaded {conversation_df.count()} conversation records")
print(f"✅ Loaded {transaction_context_df.count()} transaction context records")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Preprocessing and Cleaning

# COMMAND ----------

# Define Philippine language stop words
tagalog_stopwords = [
    'ang', 'sa', 'ng', 'at', 'na', 'ay', 'para', 'ni', 'si', 'mga', 'ko', 'mo', 'ka', 'ako', 'ikaw',
    'siya', 'tayo', 'kayo', 'sila', 'ito', 'iyan', 'iyon', 'dito', 'diyan', 'doon', 'may', 'wala',
    'hindi', 'oo', 'opo', 'po', 'ba', 'kasi', 'pero', 'tapos', 'kaya', 'kung', 'kapag', 'habang'
]

cebuano_stopwords = [
    'ang', 'sa', 'og', 'nga', 'ug', 'ni', 'si', 'mga', 'ako', 'ikaw', 'siya', 'kita', 'kamo', 'sila',
    'kini', 'kana', 'kato', 'dinhi', 'diha', 'didto', 'aduna', 'wala', 'dili', 'oo', 'mao', 'kay',
    'apan', 'unya', 'kon', 'samtang', 'hangtud'
]

# Combine all stop words
all_stopwords = list(set(
    stopwords.words('english') +
    tagalog_stopwords +
    cebuano_stopwords
))

def clean_text(text):
    """Clean and preprocess text for analysis"""
    if not text:
        return ""

    # Convert to lowercase
    text = text.lower()

    # Remove URLs, email addresses, phone numbers
    text = re.sub(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', '', text)
    text = re.sub(r'\S+@\S+', '', text)
    text = re.sub(r'\b\d{11}\b|\b\d{4}-\d{3}-\d{4}\b', '', text)  # Philippine phone numbers

    # Remove special characters but keep Filipino characters
    text = re.sub(r'[^\w\s\u00C0-\u017F]', ' ', text)

    # Remove extra whitespace
    text = ' '.join(text.split())

    return text

# Register UDF for text cleaning
clean_text_udf = F.udf(clean_text, StringType())

# Clean conversation data
cleaned_df = conversation_df.filter(
    F.col("processing_status") == "completed"
).filter(
    F.col("original_text").isNotNull()
).filter(
    F.length(F.col("original_text")) > 10
).withColumn(
    "cleaned_text",
    clean_text_udf(F.col("original_text"))
).filter(
    F.length(F.col("cleaned_text")) > 5
)

print(f"✅ Cleaned data: {cleaned_df.count()} records ready for processing")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Advanced Key Phrase Extraction and Clustering

# COMMAND ----------

# Tokenize and remove stop words
tokenizer = Tokenizer(inputCol="cleaned_text", outputCol="words")
stop_words_remover = StopWordsRemover(inputCol="words", outputCol="filtered_words", stopWords=all_stopwords)

# Create TF-IDF vectors for topic modeling
count_vectorizer = CountVectorizer(inputCol="filtered_words", outputCol="raw_features", minDF=2, maxDF=0.8)
idf = IDF(inputCol="raw_features", outputCol="features")

# Build preprocessing pipeline
preprocessing_pipeline = Pipeline(stages=[tokenizer, stop_words_remover, count_vectorizer, idf])

# Fit and transform the data
preprocessing_model = preprocessing_pipeline.fit(cleaned_df)
processed_df = preprocessing_model.transform(cleaned_df)

print("✅ Text preprocessing pipeline completed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Topic Modeling with Latent Dirichlet Allocation (LDA)

# COMMAND ----------

# Configure LDA for topic discovery
num_topics = 10  # Adjust based on data size and business needs
lda = LDA(k=num_topics, maxIter=20, seed=42, featuresCol="features", topicsCol="topic_distribution", docConcentration=0.1)

# Fit LDA model
lda_model = lda.fit(processed_df)

# Transform data to get topic distributions
topic_df = lda_model.transform(processed_df)

# Extract dominant topic for each document
def get_dominant_topic(topic_distribution):
    """Extract the dominant topic index and probability"""
    if topic_distribution:
        max_prob = max(topic_distribution)
        max_index = topic_distribution.argmax()
        return int(max_index), float(max_prob)
    return None, None

get_dominant_topic_udf = F.udf(get_dominant_topic, StructType([
    StructField("dominant_topic", IntegerType()),
    StructField("topic_probability", DoubleType())
]))

topic_enriched_df = topic_df.withColumn(
    "topic_info",
    get_dominant_topic_udf(F.col("topic_distribution"))
).withColumn(
    "dominant_topic",
    F.col("topic_info.dominant_topic")
).withColumn(
    "topic_probability",
    F.col("topic_info.topic_probability")
).drop("topic_info")

print("✅ Topic modeling completed")

# Extract topic keywords
vocab = preprocessing_model.stages[2].vocabulary
topic_keywords = []

for topic_idx in range(num_topics):
    # Get top 10 words for each topic
    topic_words = lda_model.describeTopics(maxTermsPerTopic=10).collect()[topic_idx]['termIndices']
    keywords = [vocab[int(word_idx)] for word_idx in topic_words]
    topic_keywords.append({
        'topic_id': topic_idx,
        'keywords': keywords,
        'keywords_combined': ', '.join(keywords[:5])  # Top 5 for display
    })

# Convert to DataFrame for joining
topic_keywords_df = spark.createDataFrame(topic_keywords)

print("Topic Keywords:")
for topic in topic_keywords:
    print(f"Topic {topic['topic_id']}: {topic['keywords_combined']}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Advanced Sentiment Analysis Enhancement

# COMMAND ----------

# Enhance sentiment analysis with confidence scoring and business context
def calculate_sentiment_confidence(pos_score, neu_score, neg_score):
    """Calculate sentiment confidence based on score distribution"""
    scores = [pos_score or 0, neu_score or 0, neg_score or 0]
    max_score = max(scores)
    total_score = sum(scores)

    if total_score == 0:
        return 0.0

    # Confidence is higher when one score dominates
    confidence = max_score / total_score
    return float(confidence)

def get_sentiment_intensity(sentiment_score):
    """Classify sentiment intensity"""
    if sentiment_score is None:
        return "Unknown"

    abs_score = abs(sentiment_score)
    if abs_score >= 0.7:
        return "Strong"
    elif abs_score >= 0.3:
        return "Moderate"
    else:
        return "Mild"

sentiment_confidence_udf = F.udf(calculate_sentiment_confidence, DoubleType())
sentiment_intensity_udf = F.udf(get_sentiment_intensity, StringType())

# Calculate sentiment score (positive - negative)
enhanced_sentiment_df = topic_enriched_df.withColumn(
    "sentiment_score",
    F.coalesce(F.col("sentiment_pos"), F.lit(0)) - F.coalesce(F.col("sentiment_neg"), F.lit(0))
).withColumn(
    "sentiment_confidence",
    sentiment_confidence_udf(
        F.col("sentiment_pos"),
        F.col("sentiment_neu"),
        F.col("sentiment_neg")
    )
).withColumn(
    "sentiment_intensity",
    sentiment_intensity_udf(F.col("sentiment_score"))
)

print("✅ Enhanced sentiment analysis completed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Key Phrase Analysis and Clustering

# COMMAND ----------

# Extract and analyze key phrases
def extract_phrase_insights(key_phrases_text):
    """Extract insights from key phrases"""
    if not key_phrases_text:
        return {
            'phrase_count': 0,
            'avg_phrase_length': 0.0,
            'business_keywords': [],
            'emotion_keywords': [],
            'product_keywords': []
        }

    phrases = [phrase.strip() for phrase in key_phrases_text.split(';') if phrase.strip()]

    # Business-related keywords
    business_keywords = ['service', 'staff', 'store', 'product', 'quality', 'price', 'value', 'experience', 'customer']

    # Emotion-related keywords
    emotion_keywords = ['happy', 'satisfied', 'disappointed', 'angry', 'pleased', 'frustrated', 'excited', 'concerned']

    # Product-related keywords (adjust based on your business)
    product_keywords = ['cigarette', 'tobacco', 'laundry', 'detergent', 'soap', 'brand', 'pack', 'size']

    found_business = [kw for phrase in phrases for kw in business_keywords if kw in phrase.lower()]
    found_emotion = [kw for phrase in phrases for kw in emotion_keywords if kw in phrase.lower()]
    found_product = [kw for phrase in phrases for kw in product_keywords if kw in phrase.lower()]

    return {
        'phrase_count': len(phrases),
        'avg_phrase_length': sum(len(phrase) for phrase in phrases) / len(phrases) if phrases else 0,
        'business_keywords': list(set(found_business)),
        'emotion_keywords': list(set(found_emotion)),
        'product_keywords': list(set(found_product))
    }

phrase_insights_udf = F.udf(extract_phrase_insights, StructType([
    StructField("phrase_count", IntegerType()),
    StructField("avg_phrase_length", DoubleType()),
    StructField("business_keywords", ArrayType(StringType())),
    StructField("emotion_keywords", ArrayType(StringType())),
    StructField("product_keywords", ArrayType(StringType()))
]))

# Apply phrase analysis
phrase_analyzed_df = enhanced_sentiment_df.withColumn(
    "phrase_insights",
    phrase_insights_udf(F.col("key_phrases"))
).withColumn(
    "phrase_count_enhanced",
    F.col("phrase_insights.phrase_count")
).withColumn(
    "avg_phrase_length",
    F.col("phrase_insights.avg_phrase_length")
).withColumn(
    "business_keywords",
    F.col("phrase_insights.business_keywords")
).withColumn(
    "emotion_keywords",
    F.col("phrase_insights.emotion_keywords")
).withColumn(
    "product_keywords",
    F.col("phrase_insights.product_keywords")
).drop("phrase_insights")

print("✅ Key phrase analysis completed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Customer Journey and Conversation Patterns

# COMMAND ----------

# Analyze conversation patterns and customer journey insights
def classify_conversation_type(text_length, word_count, phrase_count, sentiment):
    """Classify conversation based on engagement metrics"""

    # Length-based classification
    if text_length > 500:
        length_type = "Detailed"
    elif text_length > 100:
        length_type = "Standard"
    else:
        length_type = "Brief"

    # Engagement classification
    if word_count > 50 and phrase_count > 5:
        engagement = "High"
    elif word_count > 20 and phrase_count > 2:
        engagement = "Medium"
    else:
        engagement = "Low"

    # Conversation type based on patterns
    if sentiment == "negative" and engagement == "High":
        conversation_type = "Complaint_Detailed"
    elif sentiment == "negative":
        conversation_type = "Complaint_Brief"
    elif sentiment == "positive" and engagement == "High":
        conversation_type = "Praise_Detailed"
    elif sentiment == "positive":
        conversation_type = "Praise_Brief"
    elif engagement == "High":
        conversation_type = "Inquiry_Detailed"
    else:
        conversation_type = "Transaction_Standard"

    return {
        'length_classification': length_type,
        'engagement_level': engagement,
        'conversation_type': conversation_type
    }

conversation_classifier_udf = F.udf(classify_conversation_type, StructType([
    StructField("length_classification", StringType()),
    StructField("engagement_level", StringType()),
    StructField("conversation_type", StringType())
]))

# Apply conversation classification
journey_analyzed_df = phrase_analyzed_df.withColumn(
    "conversation_analysis",
    conversation_classifier_udf(
        F.col("text_length"),
        F.col("word_count"),
        F.col("phrase_count_enhanced"),
        F.col("sentiment")
    )
).withColumn(
    "length_classification",
    F.col("conversation_analysis.length_classification")
).withColumn(
    "engagement_level",
    F.col("conversation_analysis.engagement_level")
).withColumn(
    "conversation_type",
    F.col("conversation_analysis.conversation_type")
).drop("conversation_analysis")

print("✅ Customer journey analysis completed")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Final Data Preparation for Platinum Layer

# COMMAND ----------

# Join with topic keywords for enriched context
final_enriched_df = journey_analyzed_df.join(
    topic_keywords_df,
    journey_analyzed_df.dominant_topic == topic_keywords_df.topic_id,
    "left"
).withColumnRenamed("keywords_combined", "topic_keywords")

# Add processing metadata
platinum_df = final_enriched_df.withColumn(
    "advanced_processing_timestamp",
    F.current_timestamp()
).withColumn(
    "processing_version",
    F.lit("ScoutAI-v1.0")
).withColumn(
    "model_version",
    F.lit(f"LDA-{num_topics}topics")
)

# Select final columns for Platinum layer
platinum_final_df = platinum_df.select(
    # Original identifiers
    "canonical_tx_id",
    "interaction_id",

    # Original AI results
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

    # Enhanced analytics
    "sentiment_score",
    "sentiment_confidence",
    "sentiment_intensity",
    "cleaned_text",

    # Topic modeling results
    "dominant_topic",
    "topic_probability",
    "topic_keywords",

    # Phrase analysis
    "phrase_count_enhanced",
    "avg_phrase_length",
    "business_keywords",
    "emotion_keywords",
    "product_keywords",

    # Journey analysis
    "length_classification",
    "engagement_level",
    "conversation_type",

    # Processing metadata
    "advanced_processing_timestamp",
    "processing_version",
    "model_version"
)

print(f"✅ Platinum dataset prepared: {platinum_final_df.count()} records")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write to Platinum Layer

# COMMAND ----------

# Write enriched data to Platinum layer
platinum_final_df.write \
    .mode("overwrite") \
    .format("jdbc") \
    .option("url", jdbc_url) \
    .option("dbtable", "platinum.conversation_ai_enriched") \
    .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
    .save()

print("✅ Data successfully written to platinum.conversation_ai_enriched")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Quality Validation and Summary Statistics

# COMMAND ----------

# Generate summary statistics for validation
summary_stats = platinum_final_df.agg(
    F.count("*").alias("total_records"),
    F.countDistinct("canonical_tx_id").alias("unique_transactions"),
    F.avg("sentiment_score").alias("avg_sentiment_score"),
    F.avg("sentiment_confidence").alias("avg_sentiment_confidence"),
    F.avg("topic_probability").alias("avg_topic_probability"),
    F.countDistinct("dominant_topic").alias("unique_topics"),
    F.countDistinct("language").alias("unique_languages")
).collect()[0]

print("📊 PLATINUM LAYER SUMMARY STATISTICS")
print("=" * 50)
print(f"Total Records: {summary_stats['total_records']:,}")
print(f"Unique Transactions: {summary_stats['unique_transactions']:,}")
print(f"Average Sentiment Score: {summary_stats['avg_sentiment_score']:.3f}")
print(f"Average Sentiment Confidence: {summary_stats['avg_sentiment_confidence']:.3f}")
print(f"Average Topic Probability: {summary_stats['avg_topic_probability']:.3f}")
print(f"Unique Topics Discovered: {summary_stats['unique_topics']}")
print(f"Unique Languages: {summary_stats['unique_languages']}")

# Sentiment distribution
sentiment_dist = platinum_final_df.groupBy("sentiment", "sentiment_intensity").count().orderBy("sentiment", "sentiment_intensity").collect()

print("\n📈 SENTIMENT DISTRIBUTION")
print("=" * 30)
for row in sentiment_dist:
    print(f"{row['sentiment']} - {row['sentiment_intensity']}: {row['count']:,}")

# Topic distribution
topic_dist = platinum_final_df.groupBy("dominant_topic", "topic_keywords").count().orderBy(F.desc("count")).collect()

print("\n🎯 TOP TOPICS")
print("=" * 20)
for i, row in enumerate(topic_dist[:5]):  # Top 5 topics
    print(f"Topic {row['dominant_topic']}: {row['topic_keywords']} ({row['count']:,} conversations)")

# Conversation type distribution
conv_type_dist = platinum_final_df.groupBy("conversation_type").count().orderBy(F.desc("count")).collect()

print("\n💬 CONVERSATION TYPES")
print("=" * 25)
for row in conv_type_dist:
    print(f"{row['conversation_type']}: {row['count']:,}")

print("\n✅ Advanced conversation AI processing completed successfully!")
print("📊 Data is ready for Power BI integration and business intelligence reporting")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Export Configuration for Power BI Integration
# MAGIC
# MAGIC The processed data is now available in the following Fabric Warehouse tables:
# MAGIC
# MAGIC **Platinum Layer Tables:**
# MAGIC - `platinum.conversation_ai_enriched` - Advanced ML-enriched conversation analytics
# MAGIC
# MAGIC **Power BI Integration Notes:**
# MAGIC - Use these tables as additional fact tables in your PBIP model
# MAGIC - Create relationships via `canonical_tx_id` to link with existing `mart_tx`
# MAGIC - Add new measures for topic analysis, sentiment trends, and conversation patterns
# MAGIC - Consider creating dedicated reports for conversation analytics insights
# MAGIC
# MAGIC **Recommended DAX Measures:**
# MAGIC - Average Sentiment Score by Category/Region
# MAGIC - Topic Distribution Over Time
# MAGIC - Conversation Type Frequency
# MAGIC - Sentiment-Revenue Correlation Analysis
# MAGIC - Customer Journey Insights by Engagement Level