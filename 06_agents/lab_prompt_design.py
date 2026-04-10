# lab_prompt_design.py
# Multi-Agent Prompt Design for FDA Device Recalls
# Pairs with LAB_prompt_design.md
# Srinjoy

# This script builds a 3-agent workflow for analyzing FDA device recall data.
# Agent 1 summarizes raw data, Agent 2 identifies trends, and Agent 3 writes
# a professional executive report. Prompts were iterated to improve output.

# 0. SETUP ###################################

## 0.1 Load Packages #################################

import json  # for working with JSON

## 0.2 Load Functions #################################

# Load helper functions for agent orchestration
from functions import agent_run

## 0.3 Configuration #################################

# Select model of interest
MODEL = "smollm2:1.7b"

# Pre-formatted FDA recall data summary (based on ai_reporter.py output pattern).
# Hardcoded here so the script runs independently without API keys.
FDA_DATA_SUMMARY = """
FDA DEVICE RECALL DATA - 2024 SUMMARY
======================================
Total Recalls: 1000

TOP 10 ROOT CAUSES:
                root_cause_description  count
          Under Investigation by firm    270
                      Process Control    190
   Nonconforming Material/Component      110
                      Software Design     85
                              Design      72
                            Labeling      65
              Change Control/Process      55
                    Component Design      48
                Use Error/Ergonomics      42
                               Other     63

MONTHLY RECALL COUNTS:
   month  count
 2024-01     52
 2024-02     48
 2024-03     61
 2024-04     55
 2024-05     63
 2024-06     70
 2024-07     85
 2024-08    110
 2024-09    271
 2024-10     92
 2024-11     55
 2024-12     38

TOP 5 RECALLING FIRMS:
              recalling_firm  count
          Medline Industries    138
        Baxter International     72
       Abbott Laboratories       55
                  Medtronic      48
          Becton Dickinson       42
"""

# 1. AGENT 1: DATA SUMMARIZER ###################################

# Agent 1 receives raw aggregated data and produces a concise statistical summary.
# Prompt iteration notes:
#   v1: "Summarize this data" - too vague, produced a wall of unstructured text
#   v2: Added format reqs (bullets, key stats) - better structure but still long
#   v3: Added 100-word limit and specific items to extract - reliable, concise

role1 = (
    "You are a data summarizer for FDA device recalls. "
    "Given aggregated recall data, produce a concise statistical summary with: "
    "1) Total recall count, 2) The top 3 root causes with percentages, "
    "3) The month with the most recalls, 4) The firm with the most recalls. "
    "Use bullet points. Keep it under 100 words."
)

task1 = f"Summarize the following FDA device recall data:\n\n{FDA_DATA_SUMMARY}"

print("=" * 60)
print("📊 Agent 1: Summarizing FDA recall data...")
print("=" * 60)
result1 = agent_run(role=role1, task=task1, model=MODEL, output="text")
print(result1)
print()

# 2. AGENT 2: TREND ANALYST ###################################

# Agent 2 receives the summary and identifies notable trends and patterns.
# Prompt iteration notes:
#   v1: "Analyze these trends" - too generic, no specific insights
#   v2: Specified focus areas (seasonal, firms, root causes) - better depth
#   v3: Added "actionable insights" requirement - professional and useful

role2 = (
    "You are a trend analyst specializing in FDA medical device safety. "
    "Given a data summary of device recalls, identify 3-4 notable trends or patterns. "
    "Focus on: seasonal patterns in recall timing, concentration of recalls "
    "among specific firms, and dominant root causes that need attention. "
    "Provide actionable insights for each trend. Use numbered points. Keep under 150 words."
)

task2 = f"Analyze the following FDA recall summary and identify key trends:\n\n{result1}"

print("=" * 60)
print("🔍 Agent 2: Analyzing trends...")
print("=" * 60)
result2 = agent_run(role=role2, task=task2, model=MODEL, output="text")
print(result2)
print()

# 3. AGENT 3: REPORT WRITER ###################################

# Agent 3 receives the trend analysis and writes a professional executive brief.
# Prompt iteration notes:
#   v1: "Write a report" - unfocused, too long, no clear sections
#   v2: Added section headers and audience specification - structured output
#   v3: Added 200-word limit and formal tone requirement - polished, concise

role3 = (
    "You are a professional report writer for a regulatory audience. "
    "Given a trend analysis of FDA device recalls, write a brief executive summary "
    "with these sections:\n"
    "1. **Overview**: 2-3 sentence summary of the recall landscape\n"
    "2. **Key Findings**: 3-4 bullet points from the analysis\n"
    "3. **Recommendations**: 2-3 bullet points for manufacturers or regulators\n"
    "Use formal, professional tone. Keep under 200 words total."
)

task3 = f"Write an executive summary based on this trend analysis:\n\n{result2}"

print("=" * 60)
print("📝 Agent 3: Writing executive report...")
print("=" * 60)
result3 = agent_run(role=role3, task=task3, model=MODEL, output="text")
print(result3)
print()

# 4. FINAL RESULTS ###################################

print("\n" + "=" * 60)
print("📊 FINAL OUTPUT — All Agent Results")
print("=" * 60)

print("\n--- Agent 1: Data Summary ---")
print(result1)

print("\n--- Agent 2: Trend Analysis ---")
print(result2)

print("\n--- Agent 3: Executive Report ---")
print(result3)

print("\n✅ Multi-agent workflow complete.")
