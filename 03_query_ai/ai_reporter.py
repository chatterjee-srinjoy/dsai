# ai_reporter.py
# AI-Powered FDA Device Recall Reporter
# Pairs with LAB_ai_reporter.md
# Srinjoy

# This script queries the FDA Device Recall API for 2024 recalls,
# processes the data into a structured summary, and uses OpenAI
# to generate a useful reporting summary with insights and trends.

# 0. Setup #################################

## 0.1 Load Packages ############################

import os        # for environment variables
import requests  # for HTTP requests
import json      # for working with JSON
import pandas as pd  # for data manipulation
from dotenv import load_dotenv  # for loading .env file

## 0.2 Load Environment Variables ################

# Load environment variables from .env file
load_dotenv()

# Get API keys from environment
FDA_API_KEY = os.getenv("API_KEY")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Safety checks
if not FDA_API_KEY:
    raise ValueError("API_KEY not found in .env file. Please add your FDA API key.")
if not OPENAI_API_KEY:
    raise ValueError("OPENAI_API_KEY not found in .env file. Please add your OpenAI API key.")

# 1. Query FDA API #################################

## 1.1 Define Endpoint and Parameters ###############

# FDA Device Recall API endpoint
base_url = "https://api.fda.gov/device/recall.json"

# Query for 2024 device recalls, limit to 1000 records (FDA max)
query_params = {
    "api_key": FDA_API_KEY,
    "search": "event_date_initiated:[2024-01-01 TO 2024-12-31]",
    "limit": 1000
}

print("📡 Querying FDA Device Recall API for 2024 recalls...")

## 1.2 Make Request ##################################

response = requests.get(base_url, params=query_params)

# Check if request was successful
if response.status_code != 200:
    raise Exception(f"FDA API request failed with status {response.status_code}: {response.text}")

print(f"✅ Success! Status Code: {response.status_code}")

## 1.3 Parse Response ################################

# Parse JSON response and extract results into a DataFrame
data = response.json()
recalls = pd.DataFrame(data["results"])
print(f"📊 Total records retrieved: {len(recalls)}")

# 2. Process Data #################################

## 2.1 Clean and Select Key Columns #################

# Select relevant columns for reporting
# These fields give us a good overview of recall patterns
cols_of_interest = [
    "recall_number",
    "event_date_initiated",
    "product_code",
    "root_cause_description",
    "recalling_firm",
    "recall_status",
    "product_description"
]

# Keep only columns that exist in the data
existing_cols = [c for c in cols_of_interest if c in recalls.columns]
recalls_clean = recalls[existing_cols].copy()

## 2.2 Aggregate Summary Statistics ##################

# Count recalls by root cause
root_cause_counts = (recalls_clean
    .groupby("root_cause_description")
    .size()
    .reset_index(name="count")
    .sort_values("count", ascending=False)
    .head(10))

# Count recalls by month (extract month from date string)
recalls_clean["month"] = (recalls_clean["event_date_initiated"]
    .str[:7])  # Extract YYYY-MM format
monthly_counts = (recalls_clean
    .groupby("month")
    .size()
    .reset_index(name="count")
    .sort_values("month"))

# Count recalls by firm (top 10)
firm_counts = (recalls_clean
    .groupby("recalling_firm")
    .size()
    .reset_index(name="count")
    .sort_values("count", ascending=False)
    .head(10))

# Count recalls by status
status_counts = (recalls_clean
    .groupby("recall_status")
    .size()
    .reset_index(name="count")
    .sort_values("count", ascending=False))

## 2.3 Format Data for AI Consumption ###############

# Build a structured text summary to send to the AI model
# Summarizing first keeps token usage low and improves response quality
data_summary = f"""
FDA DEVICE RECALL DATA - 2024 SUMMARY
======================================
Total Recalls: {len(recalls_clean)}

TOP 10 ROOT CAUSES:
{root_cause_counts.to_string(index=False)}

MONTHLY RECALL COUNTS:
{monthly_counts.to_string(index=False)}

TOP 10 RECALLING FIRMS:
{firm_counts.to_string(index=False)}

RECALL STATUS BREAKDOWN:
{status_counts.to_string(index=False)}

SAMPLE PRODUCT DESCRIPTIONS (first 5):
"""

# Add a few sample product descriptions for context
for i, row in recalls_clean.head(5).iterrows():
    desc = row.get("product_description", "N/A")
    # Truncate long descriptions to keep prompt concise
    if isinstance(desc, str) and len(desc) > 200:
        desc = desc[:200] + "..."
    data_summary += f"- {desc}\n"

print("\n📋 Processed data summary:")
print(data_summary)

# 3. AI Reporting with OpenAI #################################

## 3.1 Design the Prompt ################################

# Prompt engineering: We ask for a structured report with specific sections.
# We specify format (bullet points and paragraphs), length (concise),
# and content focus (trends, insights, recommendations).
# Iteration notes:
#   v1: Asked for "a summary" - too vague, got a wall of text
#   v2: Added format instructions (bullets, sections) - better structure
#   v3: Added length constraints and focus areas - reliable, useful output

prompt = f"""You are a data analyst generating a brief executive report on FDA device recalls.

Based on the following 2024 FDA device recall data, generate a concise report with these sections:

1. **Overview**: A 2-3 sentence summary of the overall recall landscape for 2024.
2. **Key Trends**: 3-5 bullet points identifying the most notable trends (monthly patterns, common root causes, frequent recalling firms).
3. **Top Concerns**: 2-3 bullet points highlighting the most significant root causes or product categories that warrant attention.
4. **Recommendations**: 2-3 bullet points suggesting actions for device manufacturers or regulators based on the data.

Keep the total report under 300 words. Use clear, professional language suitable for a regulatory audience.

DATA:
{data_summary}
"""

## 3.2 Send Request to OpenAI ##########################

print("🤖 Sending data to OpenAI for analysis...")

# OpenAI API endpoint
openai_url = "https://api.openai.com/v1/chat/completions"

# Request body following the OpenAI chat completions format
openai_body = {
    "model": "gpt-4o-mini",  # Low-cost model, good for structured summaries
    "messages": [
        {
            "role": "user",
            "content": prompt
        }
    ]
}

# Set headers with API key
headers = {
    "Authorization": f"Bearer {OPENAI_API_KEY}",
    "Content-Type": "application/json"
}

# Send POST request to OpenAI
ai_response = requests.post(openai_url, headers=headers, json=openai_body)

# Check for errors
ai_response.raise_for_status()

## 3.3 Parse and Display AI Report #####################

# Parse the response JSON
result = ai_response.json()

# Extract the model's reply
report = result["choices"][0]["message"]["content"]

# Display the final AI-generated report
print("\n" + "=" * 60)
print("📝 AI-GENERATED FDA DEVICE RECALL REPORT")
print("=" * 60)
print(report)
print("=" * 60)

# 4. Save Report as Markdown #################################

# Save the AI-generated report as a markdown file
# Markdown is great for readability and works well on GitHub
with open("03_query_ai/report.md", "w", encoding="utf-8") as f:
    f.write(report)

print("\n✅ Saved report as report.md")
print("✅ AI Reporter complete.\n")
