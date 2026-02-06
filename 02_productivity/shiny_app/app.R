# -----------------------------------------------------------------------------
# FDA Device Recalls Dashboard
# Queries the FDA openFDA API for device recall data and displays in an
# interactive dashboard with filtering, table, and visualizations.
# -----------------------------------------------------------------------------

library(shiny)
library(bslib)
library(httr)
library(jsonlite)
library(DT)
library(plotly)
library(dplyr)

# ---- Configuration ----
FDA_BASE_URL <- "https://api.fda.gov/device/recall.json"

# Modern color palette for visualizations
COLOR_PALETTE <- c("#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", 
                   "#06B6D4", "#F97316", "#EC4899", "#6B7280", "#14B8A6")

# ---- API Functions ----

# Load API key from .env file if available
load_api_key <- function() {
  env_path <- file.path(dirname(getwd()), "01_query_api", ".env")
  if (file.exists(env_path)) {
    readRenviron(env_path)
  }
  # Also check local .env
  if (file.exists(".env")) {
    readRenviron(".env")
  }
  Sys.getenv("API_KEY")
}

# Fetch FDA device recalls with specified parameters
fetch_fda_recalls <- function(start_date, end_date, limit = 1000, api_key = NULL) {
  # Build search query for date range
  search_query <- sprintf("event_date_initiated:[%s TO %s]", start_date, end_date)
  
  # Build query parameters
  query_params <- list(
    search = search_query,
    limit = limit
  )
  
  # Add API key if available
  if (!is.null(api_key) && nchar(api_key) > 0) {
    query_params$api_key <- api_key
  }
  
  # Make API request
  response <- GET(FDA_BASE_URL, query = query_params)
  
  if (http_error(response)) {
    stop(paste("FDA API request failed with status:", status_code(response)))
  }
  
  # Parse JSON response
  raw_content <- rawToChar(response$content)
  data <- fromJSON(raw_content, flatten = TRUE)
  
  return(data)
}

# Transform raw FDA data to app-ready format
transform_recalls_data <- function(data) {
  if (is.null(data$results) || length(data$results) == 0) {
    return(NULL)
  }
  
  recalls <- data$results
  
  # Select and clean key columns
  # Available columns vary, so we check what exists
  available_cols <- names(recalls)
  
  # Define desired columns and their display names
  desired_cols <- c(
    "recall_number" = "Recall Number",
    "event_date_initiated" = "Date Initiated",
    "product_code" = "Product Code",
    "recalling_firm" = "Recalling Firm",
    "root_cause_description" = "Root Cause",
    "res_event_number" = "Event Number",
    "product_res_number" = "Product Res Number"
  )
  
  # Keep only columns that exist
  existing_cols <- intersect(names(desired_cols), available_cols)
  
  if (length(existing_cols) == 0) {
    return(recalls)
  }
  
  # Select and rename columns
  result <- recalls %>%
    select(all_of(existing_cols))
  
  return(result)
}

# ---- UI ----
ui <- page_fillable(
  theme = bs_theme(
    bootswatch = "flatly",
    primary = "#3B82F6",
    "navbar-bg" = "#1e3a5f"
  ),
  title = "FDA Device Recalls Dashboard",
  padding = 20,
  
  # Header
  div(
    class = "text-center mb-4",
    h1("FDA Device Recalls Dashboard", class = "text-primary"),
    p("Explore FDA medical device recall data from the openFDA API", 
      class = "text-muted lead")
  ),
  
  # Main layout
  layout_columns(
    col_widths = c(12, 12, 12),
    row_heights = "auto",
    
    # Card 1: Query Controls
    card(
      card_header(
        class = "bg-primary text-white",
        "Query Controls"
      ),
      card_body(
        p("Select a date range to query FDA device recalls. The API returns up to 1000 records per query."),
        layout_columns(
          col_widths = c(4, 4, 2, 2),
          dateInput(
            "start_date",
            "Start Date",
            value = as.Date("2024-01-01"),
            min = as.Date("2010-01-01"),
            max = Sys.Date()
          ),
          dateInput(
            "end_date",
            "End Date",
            value = as.Date("2024-12-31"),
            min = as.Date("2010-01-01"),
            max = Sys.Date()
          ),
          numericInput(
            "limit",
            "Max Records",
            value = 1000,
            min = 1,
            max = 1000
          ),
          actionButton(
            "fetch",
            "Fetch Data",
            class = "btn-primary mt-4",
            icon = icon("download")
          )
        ),
        uiOutput("status")
      )
    ),
    
    # Card 2: Results Table
    card(
      card_header(
        class = "bg-primary text-white",
        "Recall Records"
      ),
      card_body(
        p("Browse and filter FDA device recall records. Use the search box and column filters to find specific recalls."),
        DT::dataTableOutput("table")
      ),
      full_screen = TRUE
    ),
    
    # Card 3: Visualizations
    card(
      card_header(
        class = "bg-primary text-white",
        "Recall Analytics"
      ),
      card_body(
        layout_columns(
          col_widths = c(6, 6),
          # Root cause distribution
          div(
            h5("Top Root Causes", class = "text-center"),
            plotlyOutput("root_cause_plot", height = "350px")
          ),
          # Monthly trend
          div(
            h5("Recalls by Month", class = "text-center"),
            plotlyOutput("monthly_plot", height = "350px")
          )
        )
      ),
      full_screen = TRUE
    )
  )
)

# ---- Server ----
server <- function(input, output, session) {
  
  # Reactive value to store recall data
  recalls_df <- reactiveVal(NULL)
  api_key <- reactiveVal(NULL)
  

  # Load API key on startup
  observe({
    key <- load_api_key()
    api_key(key)
  })
  
  # Fetch data when button clicked
  observeEvent(input$fetch, {
    # Validate date range
    if (input$start_date > input$end_date) {
      output$status <- renderUI({
        div(class = "alert alert-danger mt-3",
            icon("exclamation-triangle"),
            " Error: Start date must be before end date.")
      })
      return()
    }
    
    # Show loading status
    output$status <- renderUI({
      div(class = "alert alert-info mt-3",
          icon("spinner", class = "fa-spin"),
          " Fetching data from FDA API...")
    })
    
    # Fetch data with error handling
    tryCatch({
      # Format dates for API
      start_str <- format(input$start_date, "%Y-%m-%d")
      end_str <- format(input$end_date, "%Y-%m-%d")
      
      # Fetch from API
      data <- fetch_fda_recalls(
        start_date = start_str,
        end_date = end_str,
        limit = input$limit,
        api_key = api_key()
      )
      
      # Transform data
      df <- transform_recalls_data(data)
      
      if (is.null(df) || nrow(df) == 0) {
        recalls_df(NULL)
        output$status <- renderUI({
          div(class = "alert alert-warning mt-3",
              icon("info-circle"),
              " No recalls found for the selected date range.")
        })
      } else {
        recalls_df(df)
        total_available <- data$meta$results$total
        output$status <- renderUI({
          div(class = "alert alert-success mt-3",
              icon("check-circle"),
              sprintf(" Success! Loaded %d records (Total available: %s)", 
                      nrow(df), 
                      format(total_available, big.mark = ",")))
        })
      }
      
    }, error = function(e) {
      recalls_df(NULL)
      output$status <- renderUI({
        div(class = "alert alert-danger mt-3",
            icon("exclamation-triangle"),
            paste(" Error:", conditionMessage(e)))
      })
    })
  })
  
  # Render data table
  output$table <- DT::renderDataTable({
    df <- recalls_df()
    
    if (is.null(df) || nrow(df) == 0) {
      return(NULL)
    }
    
    DT::datatable(
      df,
      filter = "top",
      options = list(
        pageLength = 15,
        scrollX = TRUE,
        autoWidth = TRUE,
        dom = "Blfrtip",
        language = list(
          emptyTable = "No data available. Click 'Fetch Data' to load recalls."
        )
      ),
      rownames = FALSE,
      class = "table-striped table-hover"
    )
  })
  
  # Root cause distribution plot
  output$root_cause_plot <- renderPlotly({
    df <- recalls_df()
    
    if (is.null(df) || nrow(df) == 0 || !"root_cause_description" %in% names(df)) {
      return(
        plot_ly() %>%
          add_annotations(
            text = "No data available.\nFetch recalls to see analytics.",
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 14, color = "#6B7280")
          ) %>%
          layout(
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE)
          )
      )
    }
    
    # Count root causes (top 10)
    root_counts <- df %>%
      mutate(root_cause = ifelse(is.na(root_cause_description) | root_cause_description == "", 
                                  "Not Specified", root_cause_description)) %>%
      count(root_cause, name = "count", sort = TRUE) %>%
      head(10) %>%
      mutate(pct = round(100 * count / sum(count), 1))
    
    # Create bar chart
    plot_ly(
      root_counts,
      y = ~reorder(root_cause, count),
      x = ~count,
      type = "bar",
      orientation = "h",
      marker = list(
        color = COLOR_PALETTE[1],
        line = list(color = "white", width = 1)
      ),
      text = ~paste0("Count: ", count, " (", pct, "%)"),
      hoverinfo = "text"
    ) %>%
      layout(
        xaxis = list(title = "Number of Recalls"),
        yaxis = list(title = "", tickfont = list(size = 10)),
        margin = list(l = 150, r = 20, t = 20, b = 40)
      ) %>%
      config(displayModeBar = FALSE)
  })
  
  # Monthly trend plot
  output$monthly_plot <- renderPlotly({
    df <- recalls_df()
    
    if (is.null(df) || nrow(df) == 0 || !"event_date_initiated" %in% names(df)) {
      return(
        plot_ly() %>%
          add_annotations(
            text = "No data available.\nFetch recalls to see analytics.",
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 14, color = "#6B7280")
          ) %>%
          layout(
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE)
          )
      )
    }
    
    # Parse dates and count by month
    monthly_counts <- df %>%
      mutate(
        date = as.Date(event_date_initiated),
        month = format(date, "%Y-%m")
      ) %>%
      filter(!is.na(month)) %>%
      count(month, name = "count") %>%
      arrange(month)
    
    if (nrow(monthly_counts) == 0) {
      return(
        plot_ly() %>%
          add_annotations(
            text = "No date data available.",
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 14, color = "#6B7280")
          ) %>%
          layout(
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE)
          )
      )
    }
    
    # Create line chart
    plot_ly(
      monthly_counts,
      x = ~month,
      y = ~count,
      type = "scatter",
      mode = "lines+markers",
      line = list(color = COLOR_PALETTE[2], width = 3),
      marker = list(color = COLOR_PALETTE[2], size = 8),
      text = ~paste0(month, ": ", count, " recalls"),
      hoverinfo = "text"
    ) %>%
      layout(
        xaxis = list(title = "Month", tickangle = -45),
        yaxis = list(title = "Number of Recalls"),
        margin = list(l = 50, r = 20, t = 20, b = 80)
      ) %>%
      config(displayModeBar = FALSE)
  })
}

# ---- Run App ----
shinyApp(ui, server)
