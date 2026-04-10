# lab_custom_rag_query.py
# RAG Query for FDA Device Recall Knowledge
# Pairs with LAB_custom_rag_query.md
# Srinjoy

# This script demonstrates Retrieval-Augmented Generation (RAG) using a local
# text file of FDA device recall domain knowledge. A search function finds
# relevant lines in the knowledge base, and the results are passed to an LLM
# to generate context-aware answers about FDA recalls.

# 0. SETUP ###################################

## 0.1 Load Packages #################################

import os    # for file path operations
import json  # for working with JSON

## 0.2 Load Functions #################################

# Load helper functions for agent orchestration
from functions import agent_run

## 0.3 Configuration #################################

# Select model of interest
MODEL = "smollm2:1.7b"
PORT = 11434
OLLAMA_HOST = f"http://localhost:{PORT}"

# Path to our FDA recall knowledge base (text data source)
DOCUMENT = "data/fda_recall_knowledge.txt"

# 1. SEARCH FUNCTION ###################################

def search_text(query, document_path):
    """
    Search a text file for lines containing the query term.

    Parameters:
    -----------
    query : str
        The search term to look for (case-insensitive)
    document_path : str
        Path to the text file to search

    Returns:
    --------
    dict
        Dictionary with query, document name, matching content, and line count
    """

    # Read the text file
    with open(document_path, 'r', encoding='utf-8') as f:
        text_content = f.readlines()

    # Find lines containing the query (case-insensitive), skip blank lines
    matching_lines = [line.strip() for line in text_content
                      if query.lower() in line.lower() and line.strip()]

    # Combine matching lines into a single text block
    result_text = "\n".join(matching_lines)

    result = {
        "query": query,
        "document": os.path.basename(document_path),
        "matching_content": result_text,
        "num_lines": len(matching_lines)
    }

    return result

# 2. TEST SEARCH FUNCTION ###################################

print("=" * 60)
print("🔧 Testing search function...")
print("=" * 60)

test_result = search_text("Class I", DOCUMENT)
print(f"✅ Found {test_result['num_lines']} matching lines for 'Class I'")
print(f"   Preview: {test_result['matching_content'][:150]}...")
print()

# 3. RAG WORKFLOW ###################################

# System prompt instructs the LLM to answer using ONLY the retrieved context.
# This prevents the model from hallucinating facts about FDA regulations.
role = (
    "You are an FDA regulatory expert. Answer the user's question about FDA device "
    "recalls using ONLY the retrieved context provided below. If the context does not "
    "contain enough information, say so. Be concise and factual. Use bullet points."
)

## 3.1 Query 1: Recall Classifications ##########################

query1 = "classification"
print("=" * 60)
print(f"🔍 RAG Query 1: '{query1}'")
print("=" * 60)

result1 = search_text(query1, DOCUMENT)
print(f"   Retrieved {result1['num_lines']} matching lines")
result1_json = json.dumps(result1, indent=2)

answer1 = agent_run(role=role, task=result1_json, model=MODEL, output="text")
print("📝 Answer:")
print(answer1)
print()

## 3.2 Query 2: Root Causes ##########################

query2 = "root cause"
print("=" * 60)
print(f"🔍 RAG Query 2: '{query2}'")
print("=" * 60)

result2 = search_text(query2, DOCUMENT)
print(f"   Retrieved {result2['num_lines']} matching lines")
result2_json = json.dumps(result2, indent=2)

answer2 = agent_run(role=role, task=result2_json, model=MODEL, output="text")
print("📝 Answer:")
print(answer2)
print()

## 3.3 Query 3: Patient Safety ##########################

query3 = "patient safety"
print("=" * 60)
print(f"🔍 RAG Query 3: '{query3}'")
print("=" * 60)

result3 = search_text(query3, DOCUMENT)
print(f"   Retrieved {result3['num_lines']} matching lines")
result3_json = json.dumps(result3, indent=2)

answer3 = agent_run(role=role, task=result3_json, model=MODEL, output="text")
print("📝 Answer:")
print(answer3)
print()

# 4. SUMMARY ###################################

print("=" * 60)
print("📊 RAG Workflow Summary")
print("=" * 60)
print(f"   📄 Knowledge base: {DOCUMENT}")
print(f"   🔍 Queries tested: 3")
print(f"   📝 Query 1 ('{query1}'): {result1['num_lines']} lines retrieved")
print(f"   📝 Query 2 ('{query2}'): {result2['num_lines']} lines retrieved")
print(f"   📝 Query 3 ('{query3}'): {result3['num_lines']} lines retrieved")
print("✅ RAG workflow complete.")
