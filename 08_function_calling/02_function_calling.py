# 02_function_calling.py
# Basic Function Calling Example
# Pairs with 02_function_calling.R
# Tim Fraser

# This script demonstrates how to use function calling with an LLM in Python.
# Students will learn how to define functions as tools and execute tool calls.

# Further reading: https://docs.ollama.com/function-calling

# 0. SETUP ###################################

## 0.1 Load Packages #################################

import requests  # for HTTP requests
import json      # for working with JSON

# If you haven't already, install the requests package...
# pip install requests

## 0.2 Configuration #################################

# Select model of interest
# Note: Function calling requires a model that supports tools (e.g., smollm2:1.7b)
MODEL = "smollm2:1.7b"

# Set the port where Ollama is running
PORT = 11434
OLLAMA_HOST = f"http://localhost:{PORT}"
CHAT_URL = f"{OLLAMA_HOST}/api/chat"

# 1. DEFINE A FUNCTION TO BE USED AS A TOOL ###################################

# Define a function to be used as a tool
# This function must be defined in the global scope so it can be called
def add_two_numbers(x, y):
    """
    Add two numbers together.
    
    Parameters:
    -----------
    x : float
        First number
    y : float
        Second number
    
    Returns:
    --------
    float
        Sum of x and y
    """
    return x + y


# Define a second function to use as a tool
def multiply_numbers(x, y):
    """
    Multiply two numbers together.
    
    Parameters:
    -----------
    x : float
        First number
    y : float
        Second number
    
    Returns:
    --------
    float
        Product of x and y
    """
    return x * y

# 2. DEFINE TOOL METADATA ###################################

# Define the tool metadata as a dictionary
# This tells the LLM what the function does and what parameters it needs
tool_add_two_numbers = {
    "type": "function",
    "function": {
        "name": "add_two_numbers",
        "description": "Add two numbers",
        "parameters": {
            "type": "object",
            "required": ["x", "y"],
            "properties": {
                "x": {
                    "type": "number",
                    "description": "first number"
                },
                "y": {
                    "type": "number",
                    "description": "second number"
                }
            }
        }
    }
}

# Tool metadata for multiply_numbers
# Same structure as add_two_numbers, but describing the multiplication function
tool_multiply_numbers = {
    "type": "function",
    "function": {
        "name": "multiply_numbers",
        "description": "Multiply two numbers",
        "parameters": {
            "type": "object",
            "required": ["x", "y"],
            "properties": {
                "x": {
                    "type": "number",
                    "description": "first number"
                },
                "y": {
                    "type": "number",
                    "description": "second number"
                }
            }
        }
    }
}

# 3. CREATE CHAT REQUEST WITH TOOLS ###################################

# Create a simple chat history with a user question that will require the tool
messages = [
    {"role": "user", "content": "What is 3 + 2?"}
]

# Both tools are available to the LLM in a single list
all_tools = [tool_add_two_numbers, tool_multiply_numbers]

# Build the request body with tools
body = {
    "model": MODEL,
    "messages": messages,
    "tools": all_tools,
    "stream": False
}

# Send the request
response = requests.post(CHAT_URL, json=body)
response.raise_for_status()
result = response.json()

# 4. EXECUTE THE TOOL CALL ###################################

# Receive back the tool call
# The LLM will return a tool_calls array with the function name and arguments
if "tool_calls" in result.get("message", {}):
    tool_calls = result["message"]["tool_calls"]
    
    # Execute each tool call
    for tool_call in tool_calls:
        func_name = tool_call["function"]["name"]
        # Arguments may be a dict or JSON string depending on Ollama version
        args = tool_call["function"]["arguments"]
        func_args = json.loads(args) if isinstance(args, str) else args
        
        # Get the function from globals and execute it
        func = globals().get(func_name)
        if func:
            output = func(**func_args)
            print(f"Tool call result: {output}")
            tool_call["output"] = output
else:
    print("No tool calls in response")

# 5. TEST THE MULTIPLY TOOL ###################################

# Now test with a multiplication question
# The LLM should pick multiply_numbers instead of add_two_numbers
messages_multiply = [
    {"role": "user", "content": "What is 7 times 6?"}
]

body_multiply = {
    "model": MODEL,
    "messages": messages_multiply,
    "tools": all_tools,
    "stream": False
}

response_multiply = requests.post(CHAT_URL, json=body_multiply)
response_multiply.raise_for_status()
result_multiply = response_multiply.json()

# Execute the multiply tool call
if "tool_calls" in result_multiply.get("message", {}):
    tool_calls_multiply = result_multiply["message"]["tool_calls"]
    
    for tool_call in tool_calls_multiply:
        func_name = tool_call["function"]["name"]
        args = tool_call["function"]["arguments"]
        func_args = json.loads(args) if isinstance(args, str) else args
        
        func = globals().get(func_name)
        if func:
            output = func(**func_args)
            print(f"Multiply tool call result: {output}")
            tool_call["output"] = output
else:
    print("No tool calls in multiply response")
