# 03_function_calling.R

# This script demonstrates how to use the ollamar package in R to interact with an LLM that supports function calling.

# Further reading: https://cran.r-project.org/web/packages/ollamar/vignettes/ollamar.html

# Load packages
require(ollamar)
require(dplyr)
require(stringr)

# Select model of interest
MODEL = "smollm2:1.7b"

# Define functions to be used as tools
add_two_numbers = function(x, y){
    return(x + y)
}

# Define a second function: multiplication
multiply_numbers = function(x, y){
    return(x * y)
}

# Define the tool metadata as a list
tool_add_two_numbers = list(
    type = "function",
    "function" = list(
        name = "add_two_numbers",
        description = "Add two numbers",
        parameters = list(
            type = "object",
            required = list("x", "y"),
            properties = list(
                x = list(type = "numeric", description = "first number"),
                y = list(type = "numeric", description = "second number")
            )
        )
    )
)

# Tool metadata for multiply_numbers
tool_multiply_numbers = list(
    type = "function",
    "function" = list(
        name = "multiply_numbers",
        description = "Multiply two numbers",
        parameters = list(
            type = "object",
            required = list("x", "y"),
            properties = list(
                x = list(type = "numeric", description = "first number"),
                y = list(type = "numeric", description = "second number")
            )
        )
    )
)

# Both tools are available to the LLM
all_tools = list(tool_add_two_numbers, tool_multiply_numbers)

# Test 1: Addition - the LLM should pick add_two_numbers
messages = create_message(role = "user", content = "What is 3 + 2?")
resp = chat(model = MODEL, messages = messages, tools = all_tools, output = "tools", stream = FALSE)

# Receive back the tool call and execute it
tool = resp[[1]]
cat("Addition tool call result:", do.call(tool$name, tool$arguments), "\n")

# Test 2: Multiplication - the LLM should pick multiply_numbers
messages2 = create_message(role = "user", content = "What is 7 times 6?")
resp2 = chat(model = MODEL, messages = messages2, tools = all_tools, output = "tools", stream = FALSE)

# Execute the multiply tool call
tool2 = resp2[[1]]
cat("Multiply tool call result:", do.call(tool2$name, tool2$arguments), "\n")

# Clean up shop
rm(list = ls())