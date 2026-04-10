# FDA Device Recall AI Agent System — Documentation

## System Architecture

### Overview

This system is a multi-agent AI pipeline that analyzes FDA medical device recalls by combining three components: **function calling** (live API queries), **Retrieval-Augmented Generation** (domain knowledge search), and **multi-agent orchestration** (chained agent roles). Three agents work together in sequence:

```
Agent 1 (Data Fetcher) ──► Agent 2 (Context Researcher) ──► Agent 3 (Executive Reporter)
   │                            │                                │
   └─ Function Calling          └─ RAG Search                    └─ Multi-Agent Synthesis
      (openFDA API tool)           (knowledge base)                 (combines both inputs)
```

### Agent Roles

| Agent | Role | Input | Output | Component |
|-------|------|-------|--------|-----------|
| Agent 1: Data Fetcher | Queries the openFDA Device Recall API using the `get_fda_recalls()` tool | LLM decides tool arguments (year, limit) | pandas DataFrame of recall records | Function Calling |
| Agent 2: Context Researcher | Searches a local knowledge base for FDA regulatory context | RAG search results (classification levels, root causes, safety info) | Synthesized domain context summary | RAG |
| Agent 3: Executive Reporter | Combines live data from Agent 1 and domain context from Agent 2 into a professional report | Data table + context summary | Executive brief with Overview, Findings, Context, Recommendations | Multi-Agent Orchestration |

---

## RAG Data Source

### Knowledge Base File

- **File**: `07_rag/data/fda_recall_knowledge.txt`
- **Type**: Plain text file (~40 lines)
- **Content**: FDA domain knowledge not available from the API, including:
  - Recall classification levels (Class I, II, III) with definitions and examples
  - Common root cause categories with explanations and prevalence
  - FDA regulatory process (CDRH, 21 CFR Part 806, recall status types)
  - Annual metrics and industry trends
  - Patient safety impact and recommended facility responses

### Search Function

- **Function**: `search_fda_knowledge(query, document_path)`
- **Method**: Case-insensitive substring matching across all lines in the text file
- **Returns**: Matching lines concatenated into a single string
- **Usage**: The system performs three targeted searches for "root cause", "Class", and "patient safety" to build comprehensive context for Agent 2

---

## Tool Functions

| Name | Purpose | Parameters | Returns |
|------|---------|------------|---------|
| `get_fda_recalls(year, limit)` | Fetch device recall data from the openFDA Device Recall API | `year` (int): Year to search, e.g. 2024. `limit` (int): Max records to return (1–1000) | pandas DataFrame with columns: `recall_number`, `date`, `firm`, `root_cause`, `product_code`, `status` |
| `search_fda_knowledge(query, document_path)` | Search the local FDA knowledge base for lines matching a query | `query` (str): Search term. `document_path` (str): Path to knowledge base text file | String of matching lines from the knowledge base |

### Tool Metadata (for LLM function calling)

The `get_fda_recalls` tool is registered with the LLM using the Ollama tools API format:

```json
{
  "type": "function",
  "function": {
    "name": "get_fda_recalls",
    "description": "Fetch device recall data from the openFDA Device Recall API.",
    "parameters": {
      "type": "object",
      "required": ["year", "limit"],
      "properties": {
        "year": { "type": "number", "description": "The year to search for recalls" },
        "limit": { "type": "number", "description": "Maximum number of results to return" }
      }
    }
  }
}
```

---

## Technical Details

### API

- **Endpoint**: `https://api.fda.gov/device/recall.json`
- **Authentication**: Optional API key (set `API_KEY` in `.env`); the API works without a key but is rate-limited
- **Query**: Lucene-style search on `event_date_initiated` field with date range filter

### LLM

- **Provider**: Ollama (local)
- **Model**: `smollm2:1.7b`
- **Host**: `http://localhost:11434`
- **API**: `/api/chat` with tools support for function calling

### Environment Variables (`.env` file at repo root)

| Variable | Purpose | Required? |
|----------|---------|-----------|
| `API_KEY` | FDA openFDA API key (higher rate limits) | Optional |
| `OLLAMA_API_KEY` | Ollama Cloud API key (not used in this system) | No |
| `OPENAI_API_KEY` | OpenAI API key (not used in this system) | No |

### Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `requests` | 2.32+ | HTTP requests to FDA API and Ollama |
| `pandas` | 3.0+ | Data manipulation and DataFrame operations |
| `python-dotenv` | 1.2+ | Loading `.env` file for API keys |
| `tabulate` | 0.10+ | `df.to_markdown()` for readable table output |

### File Structure

```
dsai/
├── .env                              # API keys (gitignored)
├── 06_agents/
│   ├── functions.py                  # Agent helper functions (course-provided)
│   └── lab_prompt_design.py          # Lab 1: Multi-agent prompt design
├── 07_rag/
│   ├── functions.py                  # RAG helper functions (course-provided)
│   ├── data/
│   │   └── fda_recall_knowledge.txt  # RAG knowledge base
│   └── lab_custom_rag_query.py       # Lab 2: RAG query workflow
└── 08_function_calling/
    ├── functions.py                  # Function calling helpers (course-provided)
    ├── lab_multi_agent_with_tools.py # Lab 3: Multi-agent with FDA API tool
    └── homework2_fda_agent.py        # Main system: all 3 components combined
```

---

## Usage Instructions

### 1. Install Dependencies

```bash
pip install requests pandas python-dotenv tabulate
```

### 2. Configure API Keys

Create a `.env` file in the repo root (or verify the existing one):

```
API_KEY=your_fda_api_key_here
```

The FDA API key is optional -- the system works without it but may be rate-limited.

### 3. Start Ollama

```bash
ollama serve
```

In a separate terminal, ensure the model is pulled:

```bash
ollama pull smollm2:1.7b
```

### 4. Run the System

**Main homework system (all 3 components):**

```bash
cd 08_function_calling
python3 homework2_fda_agent.py
```

**Individual lab scripts:**

```bash
# Lab 1: Multi-agent prompt design
cd 06_agents
python3 lab_prompt_design.py

# Lab 2: RAG query
cd 07_rag
python3 lab_custom_rag_query.py

# Lab 3: Function calling with tools
cd 08_function_calling
python3 lab_multi_agent_with_tools.py
```

Each script prints clearly labeled output for each agent's contribution.
