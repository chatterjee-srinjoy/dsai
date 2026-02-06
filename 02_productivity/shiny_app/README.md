# FDA Device Recalls Dashboard

A Shiny web application that queries the FDA openFDA API for medical device recalls and displays them in an interactive dashboard with filtering, search, and visualizations.

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Architecture](#architecture)
- [Usage Guide](#usage-guide)
- [API Requirements](#api-requirements)
- [Project Structure](#project-structure)
- [Dependencies](#dependencies)
- [Troubleshooting](#troubleshooting)

## Quick Start

**Run the app:**

```r
source("run.R")
```

Or from command line:
```bash
cd 02_productivity/shiny_app
Rscript run.R
```

**Install dependencies** (if needed):
```r
pkgs <- c("shiny", "bslib", "httr", "jsonlite", "DT", "plotly", "dplyr")
install.packages(pkgs, repos = "https://cloud.r-project.org")
```

The app will open in your default browser at `http://127.0.0.1:3838`.

## Features

- **Interactive Date Range Selection**: Query recalls for any date range from 2010 to present
- **Real-time API Queries**: Fetches data directly from the FDA openFDA API
- **Searchable Data Table**: Filter and sort recall records with instant search
- **Visual Analytics**: 
  - Top root causes bar chart
  - Monthly recall trends line chart
- **Error Handling**: Graceful handling of API errors and empty results
- **Modern UI**: Clean, responsive interface using bslib Bootstrap theming

## Architecture

```mermaid
graph TB
    subgraph UI["UI Layer"]
        U1[Query Controls Card]
        U2[Data Table Card]
        U3[Analytics Card]
    end
    subgraph Server["Server Layer"]
        S1[Reactive Values]
        S2[API Fetch Logic]
        S3[Data Transform]
        S4[Output Renderers]
    end
    subgraph External["External API"]
        E1[FDA openFDA API]
    end
    
    U1 -->|User Input| S1
    S1 --> S2
    S2 -->|HTTP GET| E1
    E1 -->|JSON Response| S3
    S3 --> S1
    S1 --> S4
    S4 --> U2
    S4 --> U3
```

## Usage Guide

### 1. Set Query Parameters

- **Start Date**: Beginning of the date range for recalls
- **End Date**: End of the date range for recalls  
- **Max Records**: Maximum number of records to fetch (1-1000)

### 2. Fetch Data

Click the **Fetch Data** button to query the FDA API. The status message will show:
- Loading indicator while fetching
- Success message with record count
- Error message if the request fails

### 3. Explore Results

- **Data Table**: Browse all recall records with:
  - Column filters at the top of each column
  - Global search box
  - Sortable columns
  - Pagination controls
  
- **Analytics Charts**:
  - **Top Root Causes**: Horizontal bar chart showing the most common reasons for recalls
  - **Monthly Trends**: Line chart showing recall frequency over time

### 4. Full Screen Mode

Click the expand icon on the Data Table or Analytics cards to view in full screen.

## API Requirements

### Without API Key

The app works without an API key but is subject to rate limits (40 requests per minute).

### With API Key (Recommended)

For higher rate limits, obtain a free API key:

1. Visit [openFDA API Keys](https://open.fda.gov/apis/authentication/)
2. Register for a free API key
3. Create a `.env` file in the `shiny_app` folder:
   ```
   API_KEY=your_api_key_here
   ```

The app automatically loads the API key from:
- `../01_query_api/.env` (original query location)
- `./.env` (local app folder)

## Project Structure

```
shiny_app/
├── app.R           # Main Shiny application (UI + Server)
├── run.R           # Launcher script with dependency check
├── DESCRIPTION     # Package metadata and dependencies
├── README.md       # This documentation
└── .env            # Optional: API key configuration
```

## Dependencies

| Package | Purpose |
|---------|---------|
| `shiny` | Web application framework |
| `bslib` | Bootstrap theming (Flatly theme) |
| `httr` | HTTP requests to FDA API |
| `jsonlite` | JSON parsing |
| `DT` | Interactive data tables |
| `plotly` | Interactive visualizations |
| `dplyr` | Data manipulation |

## Troubleshooting

### App won't start

**Missing packages**: Run the dependency installation command above.

**Port in use**: The app defaults to port 3838. If busy, R will automatically try another port.

### No data returned

- **Check date range**: Ensure start date is before end date
- **Try smaller range**: Very large ranges may timeout
- **API rate limit**: Wait a minute and try again

### API errors

- **Status 429**: Rate limit exceeded. Wait or add an API key.
- **Status 500**: FDA server error. Try again later.
- **Network error**: Check your internet connection.

---

**Based on**: [`my_good_query.R`](../../01_query_api/my_good_query.R) - Original FDA Device Recalls API query script

**API Documentation**: [openFDA Device Recall API](https://open.fda.gov/apis/device/recall/)

---

**Last Updated**: February 2026
