# lab_multi_agent_with_tools.py
# Multi-Agent System with Tools
# LAB: Multi-Agent with Function Calling

# This script builds a 2-agent workflow where Agent 1 uses a custom tool to
# fetch recent earthquake data from the USGS API, and Agent 2 analyzes the
# data and writes a summary report.

# 0. SETUP ###################################

## 0.1 Load Packages #################################

import requests  # for HTTP requests
import json      # for working with JSON
import pandas as pd  # for data manipulation
from datetime import datetime, timedelta, timezone  # for date calculations

## 0.2 Load Functions #################################

# Load helper functions for agent orchestration
from functions import agent_run, df_as_text

## 0.3 Configuration #################################

# Select model of interest
MODEL = "smollm2:1.7b"

# 1. DEFINE CUSTOM TOOL FUNCTION ###################################

# This function fetches recent earthquake data from the USGS Earthquake API.
# The USGS API is free and requires no authentication.
# Docs: https://earthquake.usgs.gov/fdsnws/event/1/

def get_earthquakes(min_magnitude=4.0, days_back=7):
    """
    Fetch recent earthquake data from the USGS Earthquake Hazards API.

    Parameters:
    -----------
    min_magnitude : float
        Minimum earthquake magnitude to include (default: 4.0)
    days_back : int
        Number of days back to search (default: 7)

    Returns:
    --------
    pandas.DataFrame
        A DataFrame of recent earthquakes with magnitude, location, and time
    """

    # USGS GeoJSON endpoint
    url = "https://earthquake.usgs.gov/fdsnws/event/1/query"

    # Calculate the start date from today
    end_date = datetime.now(timezone.utc)
    start_date = end_date - timedelta(days=days_back)

    # Build query parameters
    params = {
        "format": "geojson",
        "starttime": start_date.strftime("%Y-%m-%d"),
        "endtime": end_date.strftime("%Y-%m-%d"),
        "minmagnitude": min_magnitude,
        "orderby": "magnitude",
        "limit": 20
    }

    # Fetch data from the USGS API
    response = requests.get(url, params=params)
    response.raise_for_status()
    data = response.json()

    # Extract earthquake features into a list of dicts
    records = []
    for feature in data.get("features", []):
        props = feature["properties"]
        coords = feature["geometry"]["coordinates"]
        records.append({
            "magnitude": props.get("mag"),
            "location": props.get("place", ""),
            "time": datetime.fromtimestamp(props["time"] / 1000, tz=timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
            "depth_km": round(coords[2], 1),
            "alert_level": props.get("alert", "none"),
            "tsunami_warning": bool(props.get("tsunami", 0))
        })

    df = pd.DataFrame(records)
    return df

# 2. REGISTER TOOL IN FUNCTIONS MODULE ###################################

# The agent() wrapper in functions.py uses globals() to look up tool
# functions. We inject our function into that module so it can be found.
import functions as _fn
_fn.get_earthquakes = get_earthquakes

# 3. DEFINE TOOL METADATA ###################################

# Tool metadata tells the LLM what the function does and what arguments it expects
tool_get_earthquakes = {
    "type": "function",
    "function": {
        "name": "get_earthquakes",
        "description": "Fetch recent earthquake data from the USGS Earthquake Hazards API. Returns a table of recent earthquakes with magnitude, location, time, depth, alert level, and tsunami warning status.",
        "parameters": {
            "type": "object",
            "required": ["min_magnitude", "days_back"],
            "properties": {
                "min_magnitude": {
                    "type": "number",
                    "description": "Minimum earthquake magnitude to include (e.g. 4.0 for significant quakes, 2.5 for moderate)"
                },
                "days_back": {
                    "type": "number",
                    "description": "Number of days back to search for earthquakes (e.g. 7 for past week, 30 for past month)"
                }
            }
        }
    }
}

# 4. MULTI-AGENT WORKFLOW ###################################

# Agent 1: Data Fetcher (with tools)
# This agent uses the get_earthquakes tool to pull recent seismic activity data
role1 = "I fetch earthquake data from the USGS Earthquake Hazards API."
task1 = "Get earthquake data for magnitude 4.0 and above from the past 7 days."

print("🌍 Agent 1: Fetching earthquake data...")
result1 = agent_run(role=role1, task=task1, model=MODEL, tools=[tool_get_earthquakes])

# result1 is the DataFrame returned by the get_earthquakes tool
# Convert it to a markdown table string for the next agent
result1_text = df_as_text(result1)
print(f"  Retrieved {len(result1)} earthquake records.\n")
print(result1_text)
print()

# Agent 2: Report Writer (no tools)
# This agent receives the earthquake table and writes a short analysis
role2 = "I am a seismology analyst. I analyze earthquake data and write a concise report summarizing the key findings, including the strongest quakes, geographic patterns, and any tsunami warnings."
task2 = f"Analyze the following recent earthquake data and write a brief summary report:\n\n{result1_text}"

print("📝 Agent 2: Writing earthquake analysis report...")
result2 = agent_run(role=role2, task=task2, model=MODEL, output="text", tools=None)

# 5. VIEW RESULTS ###################################

print("\n" + "=" * 60)
print("📊 AGENT 1 — Earthquake Data (Top 5)")
print("=" * 60)
print(result1.head().to_string(index=False))

print("\n" + "=" * 60)
print("📰 AGENT 2 — Analysis Report")
print("=" * 60)
print(result2)
