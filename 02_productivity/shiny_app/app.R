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

# Cohesive color palette - FDA blue theme
PRIMARY_BLUE <- "#1e40af"
PRIMARY_LIGHT <- "#3b82f6"
ACCENT_TEAL <- "#0d9488"
ACCENT_AMBER <- "#f59e0b"
SUCCESS_GREEN <- "#10b981"
DANGER_RED <- "#ef4444"

# Chart colors - gradient blues and teals
CHART_COLORS <- c("#1e40af", "#2563eb", "#3b82f6", "#60a5fa", "#0d9488", 
                  "#14b8a6", "#2dd4bf", "#5eead4", "#f59e0b", "#fbbf24")

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

# ---- Custom CSS ----
custom_css <- "
/* Header gradient */
.dashboard-header {
  background: linear-gradient(135deg, #1e40af 0%, #0d9488 100%);
  color: white;
  padding: 2rem 1rem;
  margin: -20px -20px 1.5rem -20px;
  border-radius: 0;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}
.dashboard-header h1 {
  font-weight: 700;
  margin-bottom: 0.5rem;
  font-size: 2rem;
}
.dashboard-header p {
  opacity: 0.9;
  margin-bottom: 0;
  font-size: 1.1rem;
}

/* Card styling */
.card {
  border: none;
  box-shadow: 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06);
  border-radius: 12px;
  overflow: hidden;
}
.card-header {
  font-weight: 600;
  font-size: 1rem;
  padding: 1rem 1.25rem;
  border-bottom: 1px solid rgba(0,0,0,0.05);
}
.card-body {
  padding: 1.25rem;
}

/* Metric cards */
.metric-card {
  background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
  border-radius: 10px;
  padding: 1rem;
  text-align: center;
  border: 1px solid #e2e8f0;
}
.metric-value {
  font-size: 1.75rem;
  font-weight: 700;
  color: #1e40af;
}
.metric-label {
  font-size: 0.85rem;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* Button styling */
.btn-primary {
  background: linear-gradient(135deg, #1e40af 0%, #2563eb 100%);
  border: none;
  font-weight: 500;
  padding: 0.625rem 1.25rem;
  border-radius: 8px;
  transition: all 0.2s;
}
.btn-primary:hover {
  background: linear-gradient(135deg, #1e3a8a 0%, #1d4ed8 100%);
  transform: translateY(-1px);
  box-shadow: 0 4px 6px -1px rgba(30, 64, 175, 0.3);
}

/* Input styling */
.form-control, .form-select {
  border-radius: 8px;
  border: 1px solid #e2e8f0;
}
.form-control:focus, .form-select:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.15);
}

/* Alert styling */
.alert {
  border-radius: 10px;
  border: none;
}
.alert-success {
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 100%);
  color: #065f46;
}
.alert-info {
  background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
  color: #1e40af;
}
.alert-danger {
  background: linear-gradient(135deg, #fef2f2 0%, #fee2e2 100%);
  color: #991b1b;
}
.alert-warning {
  background: linear-gradient(135deg, #fffbeb 0%, #fef3c7 100%);
  color: #92400e;
}

/* Chart titles */
.chart-title {
  font-weight: 600;
  color: #1e293b;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 2px solid #e2e8f0;
}

/* Table styling */
.dataTables_wrapper {
  font-size: 0.9rem;
}
table.dataTable thead th {
  background: #f8fafc;
  font-weight: 600;
  color: #475569;
}
"

# ---- UI ----
ui <- page_fillable(
  theme = bs_theme(
    version = 5,
    bootswatch = "litera",
    primary = "#1e40af",
    secondary = "#64748b",
    success = "#10b981",
    info = "#0d9488",
    warning = "#f59e0b",
    danger = "#ef4444",
    base_font = font_google("Inter"),
    heading_font = font_google("Inter"),
    "border-radius" = "0.5rem"
  ),
  title = "FDA Device Recalls Dashboard",
  padding = 20,
  
  # Inject custom CSS
  tags$head(tags$style(HTML(custom_css))),
  
  # Header with gradient
  div(
    class = "dashboard-header text-center",
    h1(icon("shield-virus"), " FDA Device Recalls Dashboard"),
    p("Explore medical device recall data from the openFDA API")
  ),
  
  # Main layout - responsive grid
  layout_columns(
    col_widths = c(12),
    
    # Row 1: Query Controls
    card(
      card_header(
        class = "bg-white",
        div(class = "d-flex align-items-center",
            icon("sliders", class = "me-2 text-primary"),
            span("Query Controls", class = "text-primary"))
      ),
      card_body(
        layout_columns(
          col_widths = c(3, 3, 2, 2, 2),
          gap = "1rem",
          dateInput(
            "start_date",
            tags$span(icon("calendar-alt", class = "me-1"), "Start Date"),
            value = as.Date("2024-01-01"),
            min = as.Date("2010-01-01"),
            max = Sys.Date()
          ),
          dateInput(
            "end_date",
            tags$span(icon("calendar-alt", class = "me-1"), "End Date"),
            value = as.Date("2024-12-31"),
            min = as.Date("2010-01-01"),
            max = Sys.Date()
          ),
          numericInput(
            "limit",
            tags$span(icon("list-ol", class = "me-1"), "Max Records"),
            value = 1000,
            min = 1,
            max = 1000
          ),
          div(
            style = "padding-top: 32px;",
            actionButton(
              "fetch",
              tags$span(icon("search"), " Fetch Data"),
              class = "btn-primary w-100"
            )
          ),
          div(
            style = "padding-top: 32px;",
            uiOutput("record_count")
          )
        ),
        uiOutput("status")
      )
    )
  ),
  
  # Row 2: Summary Metrics
  uiOutput("metrics_row"),
  
  # Row 3: Table and Charts side by side
  layout_columns(
    col_widths = c(7, 5),
    
    # Left: Data Table
    card(
      card_header(
        class = "bg-white",
        div(class = "d-flex align-items-center justify-content-between",
            div(icon("table", class = "me-2 text-primary"),
                span("Recall Records", class = "text-primary")),
            tags$small(class = "text-muted", "Click column headers to sort"))
      ),
      card_body(
        style = "padding: 0.75rem;",
        DT::dataTableOutput("table")
      ),
      full_screen = TRUE,
      height = "500px"
    ),
    
    # Right: Charts stacked
    layout_columns(
      col_widths = c(12, 12),
      
      # Top Root Causes
      card(
        card_header(
          class = "bg-white",
          div(icon("chart-bar", class = "me-2 text-primary"),
              span("Top Root Causes", class = "text-primary"))
        ),
        card_body(
          style = "padding: 0.5rem;",
          plotlyOutput("root_cause_plot", height = "200px")
        ),
        full_screen = TRUE
      ),
      
      # Monthly Trend
      card(
        card_header(
          class = "bg-white",
          div(icon("chart-line", class = "me-2 text-primary"),
              span("Monthly Trend", class = "text-primary"))
        ),
        card_body(
          style = "padding: 0.5rem;",
          plotlyOutput("monthly_plot", height = "200px")
        ),
        full_screen = TRUE
      )
    )
  ),
  
  # Footer
  div(
    class = "text-center text-muted mt-4 pt-3",
    style = "border-top: 1px solid #e2e8f0; font-size: 0.85rem;",
    p(
      "Data source: ",
      tags$a(href = "https://open.fda.gov/apis/device/recall/", 
             target = "_blank", "openFDA Device Recall API"),
      " | Built with R Shiny"
    )
  )
)

# ---- Server ----
server <- function(input, output, session) {
  
  # Reactive value to store recall data
  recalls_df <- reactiveVal(NULL)
  api_key <- reactiveVal(NULL)
  total_available <- reactiveVal(0)

  # Load API key on startup
  observe({
    key <- load_api_key()
    api_key(key)
  })
  
  # Record count display
  output$record_count <- renderUI({
    df <- recalls_df()
    if (is.null(df)) {
      div(class = "metric-card",
          div(class = "metric-value", "—"),
          div(class = "metric-label", "Records"))
    } else {
      div(class = "metric-card",
          div(class = "metric-value", format(nrow(df), big.mark = ",")),
          div(class = "metric-label", "Records"))
    }
  })
  
  # Metrics row
  output$metrics_row <- renderUI({
    df <- recalls_df()
    
    if (is.null(df) || nrow(df) == 0) {
      return(NULL)
    }
    
    # Calculate metrics
    n_recalls <- nrow(df)
    n_firms <- if ("recalling_firm" %in% names(df)) length(unique(df$recalling_firm)) else 0
    n_causes <- if ("root_cause_description" %in% names(df)) length(unique(df$root_cause_description[!is.na(df$root_cause_description)])) else 0
    total_avail <- total_available()
    
    layout_columns(
      col_widths = c(3, 3, 3, 3),
      style = "margin-bottom: 1rem;",
      
      div(class = "metric-card",
          div(class = "metric-value", style = "color: #1e40af;", 
              format(n_recalls, big.mark = ",")),
          div(class = "metric-label", "Records Loaded")),
      
      div(class = "metric-card",
          div(class = "metric-value", style = "color: #0d9488;",
              format(total_avail, big.mark = ",")),
          div(class = "metric-label", "Total Available")),
      
      div(class = "metric-card",
          div(class = "metric-value", style = "color: #7c3aed;",
              format(n_firms, big.mark = ",")),
          div(class = "metric-label", "Unique Firms")),
      
      div(class = "metric-card",
          div(class = "metric-value", style = "color: #f59e0b;",
              format(n_causes, big.mark = ",")),
          div(class = "metric-label", "Root Causes"))
    )
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
        total_available(0)
        output$status <- renderUI({
          div(class = "alert alert-warning mt-3",
              icon("info-circle"),
              " No recalls found for the selected date range.")
        })
      } else {
        recalls_df(df)
        total_available(data$meta$results$total)
        output$status <- renderUI({
          div(class = "alert alert-success mt-3",
              icon("check-circle"),
              sprintf(" Successfully loaded %d records!", nrow(df)))
        })
      }
      
    }, error = function(e) {
      recalls_df(NULL)
      total_available(0)
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
    
    # Rename columns for display
    display_names <- c(
      "recall_number" = "Recall #",
      "event_date_initiated" = "Date",
      "product_code" = "Product Code",
      "recalling_firm" = "Firm",
      "root_cause_description" = "Root Cause"
    )
    
    display_df <- df
    for (old_name in names(display_names)) {
      if (old_name %in% names(display_df)) {
        names(display_df)[names(display_df) == old_name] <- display_names[old_name]
      }
    }
    
    DT::datatable(
      display_df,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = "320px",
        autoWidth = FALSE,
        dom = "frtip",
        language = list(
          emptyTable = "No data available. Click 'Fetch Data' to load recalls.",
          search = "Search:",
          info = "Showing _START_ to _END_ of _TOTAL_ records"
        ),
        columnDefs = list(
          list(width = "100px", targets = 0),
          list(width = "90px", targets = 1),
          list(className = "dt-left", targets = "_all")
        ),
        initComplete = JS(
          "function(settings, json) {",
          "  $(this.api().table().header()).css({'background-color': '#f8fafc', 'color': '#475569'});",
          "}"
        )
      ),
      rownames = FALSE,
      class = "table table-sm table-hover compact",
      style = "bootstrap5"
    )
  })
  
  # Root cause distribution plot
  output$root_cause_plot <- renderPlotly({
    df <- recalls_df()
    
    if (is.null(df) || nrow(df) == 0 || !"root_cause_description" %in% names(df)) {
      return(
        plot_ly() %>%
          add_annotations(
            text = "Click 'Fetch Data' to load recalls",
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 12, color = "#94a3b8")
          ) %>%
          layout(
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            paper_bgcolor = "rgba(0,0,0,0)",
            plot_bgcolor = "rgba(0,0,0,0)"
          )
      )
    }
    
    # Count root causes (top 6 for compact view)
    root_counts <- df %>%
      mutate(root_cause = ifelse(is.na(root_cause_description) | root_cause_description == "", 
                                  "Not Specified", root_cause_description)) %>%
      count(root_cause, name = "count", sort = TRUE) %>%
      head(6) %>%
      mutate(
        pct = round(100 * count / sum(count), 1),
        # Truncate long labels
        root_cause_short = ifelse(nchar(root_cause) > 25, 
                                   paste0(substr(root_cause, 1, 22), "..."), 
                                   root_cause)
      )
    
    # Create horizontal bar chart with gradient colors
    plot_ly(
      root_counts,
      y = ~reorder(root_cause_short, count),
      x = ~count,
      type = "bar",
      orientation = "h",
      marker = list(
        color = ~count,
        colorscale = list(c(0, "#60a5fa"), c(1, "#1e40af")),
        line = list(color = "white", width = 1)
      ),
      text = ~paste0(count, " (", pct, "%)"),
      textposition = "outside",
      hovertemplate = paste0(
        "<b>%{y}</b><br>",
        "Recalls: %{x}<br>",
        "<extra></extra>"
      )
    ) %>%
      layout(
        xaxis = list(
          title = "",
          showgrid = TRUE,
          gridcolor = "#f1f5f9",
          zeroline = FALSE
        ),
        yaxis = list(
          title = "",
          tickfont = list(size = 10, color = "#475569")
        ),
        margin = list(l = 120, r = 50, t = 10, b = 30),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
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
            text = "Click 'Fetch Data' to load recalls",
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 12, color = "#94a3b8")
          ) %>%
          layout(
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            paper_bgcolor = "rgba(0,0,0,0)",
            plot_bgcolor = "rgba(0,0,0,0)"
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
            text = "No date data available",
            x = 0.5, y = 0.5,
            xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 12, color = "#94a3b8")
          ) %>%
          layout(
            xaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            yaxis = list(showgrid = FALSE, showticklabels = FALSE, zeroline = FALSE),
            paper_bgcolor = "rgba(0,0,0,0)",
            plot_bgcolor = "rgba(0,0,0,0)"
          )
      )
    }
    
    # Create area chart with gradient fill
    plot_ly(
      monthly_counts,
      x = ~month,
      y = ~count,
      type = "scatter",
      mode = "lines+markers",
      fill = "tozeroy",
      fillcolor = "rgba(13, 148, 136, 0.15)",
      line = list(color = "#0d9488", width = 3, shape = "spline"),
      marker = list(color = "#0d9488", size = 8, line = list(color = "white", width = 2)),
      hovertemplate = paste0(
        "<b>%{x}</b><br>",
        "Recalls: %{y}<br>",
        "<extra></extra>"
      )
    ) %>%
      layout(
        xaxis = list(
          title = "",
          tickangle = -45,
          tickfont = list(size = 9, color = "#475569"),
          showgrid = FALSE,
          zeroline = FALSE
        ),
        yaxis = list(
          title = "",
          tickfont = list(size = 10, color = "#475569"),
          showgrid = TRUE,
          gridcolor = "#f1f5f9",
          zeroline = FALSE
        ),
        margin = list(l = 40, r = 20, t = 10, b = 60),
        paper_bgcolor = "rgba(0,0,0,0)",
        plot_bgcolor = "rgba(0,0,0,0)"
      ) %>%
      config(displayModeBar = FALSE)
  })
}

# ---- Run App ----
shinyApp(ui, server)
