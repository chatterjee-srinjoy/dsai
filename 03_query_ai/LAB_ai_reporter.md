# 📌 LAB

## Build an AI-Powered Data Reporter

🕒 *Estimated Time: 30 minutes*

---

## 📋 Lab Overview

Create a script that queries your API from [`LAB_your_good_api_query.md`](../01_query_api/LAB_your_good_api_query.md), processes the data, and uses AI (Ollama local/cloud or OpenAI) to generate a useful reporting summary. Iterate on your prompts to refine the output format and quality.

---

## ✅ Your Tasks

### Task 1: Prepare Data Pipeline

- [x] Use your API query script from the previous lab (or create a new one)
- [x] Process the API data: clean, filter, or aggregate as needed for reporting
- [x] Format the processed data for AI consumption (e.g., JSON, CSV, or structured text)

### Task 2: Design Your AI Prompt

- [x] Decide what you want the AI to return:
  - Summary statistics or insights?
  - Trends or patterns?
  - Recommendations or analysis?
  - Specific format (bullets, paragraphs, tables)?
- [x] Write an initial prompt that includes your processed data and clear instructions
- [x] Test with Ollama (local or cloud) or OpenAI using your example scripts

### Task 3: Iterate and Refine

- [x] Run your script and review the AI output
- [x] Refine your prompt based on results:
  - Adjust length requirements (e.g., "2-3 sentences" or "brief summary")
  - Specify format (e.g., "Use bullet points" or "Write in paragraph form")
  - Clarify what content to focus on
- [x] Test 2-3 iterations until output is reliable and useful
- [x] Write a couple sentences describing your process and why it works

### Prompt Design Explanation

My prompt went through 3 iterations. Version 1 simply asked for "a summary" of the data, which produced unfocused, lengthy output. Version 2 added explicit section headers (Overview, Key Trends, Top Concerns, Recommendations) and formatting instructions (bullet points), which gave the report much better structure. Version 3 added a 300-word length constraint and specified the target audience ("regulatory audience"), which made the output concise and professional. The key insight is that pre-aggregating data before sending it to the AI (e.g., top 10 root causes, monthly counts) reduces token usage and helps the model focus on patterns rather than raw records.

---

## 💡 Tips and Resources

- **Prompt Design**: Be specific about format, length, and content focus. Examples: "Generate a 3-sentence summary" or "List the top 5 insights as bullet points"
- **Data Formatting**: Consider summarizing data before sending to AI to reduce token usage and improve focus
- **Iteration**: Start broad, then narrow down. Test what works and refine based on actual outputs
- **Example Scripts**: Reference [`02_ollama.py`](02_ollama.py), [`02_ollama.R`](02_ollama.R), [`03_ollama_cloud.py`](03_ollama_cloud.py), [`04_openai.py`](04_openai.py) for AI query patterns

---

## 📤 To Submit

- For credit: Submit:
  1. Your complete script (API query + data processing + AI reporting)
  2. Screenshot showing the final AI-generated report
  3. Brief explanation (2-3 sentences) of your prompt design choices and how you iterated to improve results

---

![](../docs/images/icons.png)

---

← 🏠 [Back to Top](#LAB)
