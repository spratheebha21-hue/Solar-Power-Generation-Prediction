library(shiny)
library(dplyr)
library(ggplot2)
library(plotly)

supported_features <- c(
  "solar_radiation", "cloud_cover", "temperature", "humidity",
  "wind_speed", "precipitation", "sunshine_hours"
)

feature_labels <- c(
  solar_radiation = "Solar radiation (W/m2)",
  cloud_cover = "Cloud cover (%)",
  temperature = "Temperature (C)",
  humidity = "Relative humidity (%)",
  wind_speed = "Wind speed (km/h)",
  precipitation = "Precipitation (mm)",
  sunshine_hours = "Sunshine hours"
)

normalize_column_names <- function(column_names) {
  normalized <- tolower(trimws(column_names))
  normalized <- gsub("[^a-z0-9]+", "_", normalized)
  gsub("^_|_$", "", normalized)
}

parse_dates <- function(values) {
  if (inherits(values, "Date")) {
    return(values)
  }

  date_text <- trimws(as.character(values))
  parsed <- suppressWarnings(as.Date(date_text))
  formats <- c("%m/%d/%Y", "%d/%m/%Y", "%Y/%m/%d", "%m-%d-%Y", "%d-%m-%Y")

  for (date_format in formats) {
    missing_dates <- is.na(parsed) & !is.na(date_text) & nzchar(date_text)
    if (!any(missing_dates)) {
      break
    }
    parsed[missing_dates] <- suppressWarnings(as.Date(date_text[missing_dates], format = date_format))
  }

  parsed
}

read_and_validate_csv <- function(file_path) {
  raw_data <- tryCatch(
    read.csv(file_path, stringsAsFactors = FALSE, check.names = FALSE),
    error = function(error) stop(paste("Could not read the CSV:", conditionMessage(error)))
  )

  names(raw_data) <- normalize_column_names(names(raw_data))
  required_columns <- c("date", "generation_kwh")
  missing_columns <- setdiff(required_columns, names(raw_data))

  if (length(missing_columns) > 0) {
    stop(paste(
      "Missing required column(s):",
      paste(missing_columns, collapse = ", "),
      ". Required columns are date and generation_kwh."
    ))
  }

  cleaned_data <- data.frame(
    date = parse_dates(raw_data$date),
    generation_kwh = suppressWarnings(as.numeric(raw_data$generation_kwh)),
    stringsAsFactors = FALSE
  )

  available_features <- intersect(supported_features, names(raw_data))
  for (feature in available_features) {
    cleaned_data[[feature]] <- suppressWarnings(as.numeric(raw_data[[feature]]))
  }

  valid_rows <- !is.na(cleaned_data$date) &
    is.finite(cleaned_data$generation_kwh) &
    cleaned_data$generation_kwh >= 0
  excluded_rows <- sum(!valid_rows)
  cleaned_data <- cleaned_data[valid_rows, , drop = FALSE]
  cleaned_data <- cleaned_data[order(cleaned_data$date), , drop = FALSE]
  rownames(cleaned_data) <- NULL

  if (nrow(cleaned_data) == 0) {
    stop("No usable rows remain. Check that dates are valid and generation_kwh is numeric and non-negative.")
  }

  list(
    data = cleaned_data,
    excluded_rows = excluded_rows,
    ignored_columns = setdiff(names(raw_data), c(required_columns, available_features))
  )
}

sample_result <- read_and_validate_csv(file.path("data", "sample_solar_data.csv"))

page_theme <- "
  :root { --forest: #194d3b; --leaf: #367b55; --sun: #f3c84b; --ink: #1c3028; --muted: #66766e; --paper: #f5f7f2; }
  body { background: var(--paper); color: var(--ink); font-family: 'Aptos', 'Segoe UI', sans-serif; }
  .navbar { background: var(--forest); border: 0; border-radius: 0; }
  .navbar-default .navbar-brand, .navbar-default .navbar-nav > li > a { color: #f8f6ed; }
  .navbar-default .navbar-nav > .active > a, .navbar-default .navbar-nav > .active > a:hover { background: var(--leaf); color: white; }
  .navbar-default .navbar-brand:hover, .navbar-default .navbar-nav > li > a:hover { color: var(--sun); }
  .container-fluid { max-width: 1440px; }
  .page-heading { padding: 24px 0 14px; border-bottom: 1px solid #d9e1d8; margin-bottom: 20px; }
  .page-heading h2 { margin: 0 0 5px; font-size: 25px; font-weight: 700; }
  .page-heading p, .help-copy { color: var(--muted); }
  .metric-grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 18px 0 24px; }
  .metric { background: white; border: 1px solid #dce5da; border-top: 3px solid var(--leaf); padding: 15px 17px; min-height: 98px; }
  .metric-label { color: var(--muted); font-size: 13px; }
  .metric-value { color: var(--forest); font-size: 25px; font-weight: 700; margin-top: 7px; overflow-wrap: anywhere; }
  .chart-panel { background: white; border: 1px solid #dce5da; padding: 12px 14px; margin-bottom: 16px; }
  .chart-panel h3 { font-size: 17px; margin: 4px 0 10px; }
  .section-title { margin: 20px 0 10px; font-size: 18px; font-weight: 700; }
  .notice { padding: 10px 13px; background: #fff8df; border-left: 4px solid var(--sun); margin: 12px 0; }
  .error { color: #9b3027; font-weight: 600; }
  .btn-primary { background: var(--forest); border-color: var(--forest); }
  .btn-primary:hover { background: var(--leaf); border-color: var(--leaf); }
  .form-control:focus { border-color: var(--leaf); box-shadow: 0 0 0 2px #367b5522; }
  @media (max-width: 850px) { .metric-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  @media (max-width: 480px) { .metric-grid { grid-template-columns: 1fr 1fr; gap: 8px; } .metric { padding: 11px; } .metric-value { font-size: 20px; } }
"

ui <- navbarPage(
  title = "Solar / Forecast",
  header = tags$head(tags$style(HTML(page_theme))),
  tabPanel(
    "Overview",
    fluidPage(
      div(class = "page-heading", h2("Solar generation overview"),
          p("Explore daily output, seasonal totals, and weather relationships.")),
      uiOutput("data_notice"),
      uiOutput("metric_cards"),
      uiOutput("date_filter_ui"),
      fluidRow(
        column(12, div(class = "chart-panel", h3("Daily generation"), plotlyOutput("daily_plot", height = "330px")))
      ),
      fluidRow(
        column(6, div(class = "chart-panel", h3("Monthly generation"), plotlyOutput("monthly_plot", height = "310px"))),
        column(6, div(class = "chart-panel", h3("Weather and generation"), uiOutput("weather_filter_ui"), plotlyOutput("weather_plot", height = "270px")))
      )
    )
  ),
  tabPanel(
    "Predict",
    fluidPage(
      div(class = "page-heading", h2("Predict daily generation"),
          p("Enter weather conditions to estimate one day's solar electricity output.")),
      uiOutput("model_notice"),
      uiOutput("prediction_inputs"),
      actionButton("predict_button", "Predict generation", class = "btn-primary"),
      br(), br(),
      uiOutput("prediction_result"),
      div(class = "chart-panel", h3("Actual vs predicted (chronological test set)"),
          plotlyOutput("actual_predicted_plot", height = "340px")),
      h4(class = "section-title", "Model evaluation"),
      tableOutput("model_metrics"),
      p(class = "help-copy", "Accuracy depends on the quality, coverage, and quantity of historical data. A simulated sample only demonstrates the workflow; it does not establish real-world accuracy."),
      downloadButton("download_prediction", "Download prediction CSV")
    )
  ),
  tabPanel(
    "Data & reports",
    fluidPage(
      div(class = "page-heading", h2("Historical data and reports"),
          p("Upload a CSV to replace the active dataset, inspect cleaned records, or export a summary.")),
      fluidRow(
        column(7, fileInput("dataset_file", "Upload historical CSV", accept = ".csv")),
        column(5, br(), actionButton("use_sample", "Use included sample dataset"))
      ),
      uiOutput("upload_message"),
      p(class = "help-copy", "Required columns: date and generation_kwh. Supported optional weather columns: solar_radiation, cloud_cover, temperature, humidity, wind_speed, precipitation, sunshine_hours. Invalid dates, non-numeric or negative generation rows are excluded; missing weather values are imputed from training data."),
      h4(class = "section-title", "Cleaned historical records"),
      tableOutput("historical_table"),
      downloadButton("download_summary", "Download historical summary CSV")
    )
  )
)

server <- function(input, output, session) {
  active_data <- reactiveVal(list(
    data = sample_result$data,
    source = "Included simulated sample data",
    excluded_rows = sample_result$excluded_rows,
    ignored_columns = sample_result$ignored_columns
  ))
  upload_message <- reactiveVal(NULL)

  observeEvent(input$dataset_file, {
    req(input$dataset_file$datapath)
    result <- tryCatch(
      read_and_validate_csv(input$dataset_file$datapath),
      error = function(error) error
    )

    if (inherits(result, "error")) {
      upload_message(paste("Upload not applied:", conditionMessage(result)))
      return()
    }

    active_data(list(
      data = result$data,
      source = paste("Uploaded:", input$dataset_file$name),
      excluded_rows = result$excluded_rows,
      ignored_columns = result$ignored_columns
    ))
    upload_message("CSV loaded. The uploaded file is now the active dataset.")
  })

  observeEvent(input$use_sample, {
    active_data(list(
      data = sample_result$data,
      source = "Included simulated sample data",
      excluded_rows = sample_result$excluded_rows,
      ignored_columns = sample_result$ignored_columns
    ))
    upload_message("The included simulated sample dataset is now active.")
  })

  model_result <- reactive({
    current <- active_data()
    data <- current$data
    total_rows <- nrow(data)

    if (total_rows < 5) {
      return(list(ok = FALSE, message = "At least 5 usable rows are needed for a chronological train/test split."))
    }

    split_index <- floor(total_rows * 0.8)
    training <- data[seq_len(split_index), , drop = FALSE]
    testing <- data[seq.int(split_index + 1, total_rows), , drop = FALSE]
    candidate_features <- intersect(supported_features, names(data))
    medians <- list()
    usable_features <- character()

    for (feature in candidate_features) {
      training_values <- training[[feature]]
      observed_values <- training_values[is.finite(training_values)]
      if (length(observed_values) == 0 || length(unique(observed_values)) < 2) {
        next
      }
      medians[[feature]] <- median(observed_values)
      training[[feature]][!is.finite(training[[feature]])] <- medians[[feature]]
      testing[[feature]][!is.finite(testing[[feature]])] <- medians[[feature]]
      usable_features <- c(usable_features, feature)
    }

    if (length(usable_features) == 0) {
      return(list(ok = FALSE, message = "No usable weather columns found. Add at least one varying supported numeric weather column."))
    }
    if (nrow(training) <= length(usable_features) + 1) {
      return(list(ok = FALSE, message = "There are too few training rows for the available weather columns. Add more history or remove some weather columns."))
    }

    model <- tryCatch(
      suppressWarnings(lm(reformulate(usable_features, response = "generation_kwh"), data = training)),
      error = function(error) error
    )
    if (inherits(model, "error")) {
      return(list(ok = FALSE, message = paste("Model training failed:", conditionMessage(model))))
    }

    test_predictions <- tryCatch(
      as.numeric(predict(model, newdata = testing)),
      error = function(error) rep(NA_real_, nrow(testing))
    )
    test_predictions <- pmax(0, test_predictions)

    if (length(test_predictions) != nrow(testing) || any(!is.finite(test_predictions))) {
      return(list(ok = FALSE, message = "The model could not make stable test predictions. Check for redundant or strongly related weather columns."))
    }

    actual <- testing$generation_kwh
    list(
      ok = TRUE,
      model = model,
      features = usable_features,
      medians = medians,
      training = training,
      testing = testing,
      test_predictions = test_predictions,
      mae = mean(abs(actual - test_predictions)),
      rmse = sqrt(mean((actual - test_predictions)^2)),
      data = data
    )
  })

  output$data_notice <- renderUI({
    current <- active_data()
    message <- paste0("Active dataset: ", current$source, " | ", nrow(current$data), " usable rows")
    details <- character()
    if (current$excluded_rows > 0) {
      details <- c(details, paste(current$excluded_rows, "invalid row(s) excluded"))
    }
    if (length(current$ignored_columns) > 0) {
      details <- c(details, paste("Ignored unsupported column(s):", paste(current$ignored_columns, collapse = ", ")))
    }
    div(class = "notice", strong(message), if (length(details) > 0) p(paste(details, collapse = ". ")))
  })

  output$metric_cards <- renderUI({
    data <- active_data()$data
    metric_card <- function(label, value) {
      div(class = "metric", div(class = "metric-label", label), div(class = "metric-value", value))
    }
    div(class = "metric-grid",
        metric_card("Total generation", paste(format(round(sum(data$generation_kwh), 1), big.mark = ","), "kWh")),
        metric_card("Average per day", paste(format(round(mean(data$generation_kwh), 1), big.mark = ","), "kWh")),
        metric_card("Highest day", paste(format(round(max(data$generation_kwh), 1), big.mark = ","), "kWh")),
        metric_card("Latest prediction", {
          result <- prediction_result()
          if (is.null(result) || !is.null(result$error)) "Not run" else paste(round(result$prediction, 1), "kWh")
        })
    )
  })

  output$date_filter_ui <- renderUI({
    data <- active_data()$data
    dateRangeInput("date_range", "Chart date range", start = min(data$date), end = max(data$date), min = min(data$date), max = max(data$date))
  })

  filtered_data <- reactive({
    data <- active_data()$data
    if (is.null(input$date_range) || length(input$date_range) != 2 || any(is.na(input$date_range))) {
      return(data)
    }
    data %>% filter(date >= input$date_range[1], date <= input$date_range[2])
  })

  output$daily_plot <- renderPlotly({
    data <- filtered_data()
    plot <- ggplot(data, aes(date, generation_kwh)) +
      geom_line(color = "#367b55", linewidth = 0.8) +
      geom_point(color = "#d29d18", size = 1.5) +
      labs(x = NULL, y = "Generation (kWh)") +
      theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank())
    ggplotly(plot, tooltip = c("x", "y"))
  })

  output$monthly_plot <- renderPlotly({
    monthly_data <- filtered_data() %>%
      mutate(month = as.Date(format(date, "%Y-%m-01"))) %>%
      group_by(month) %>%
      summarise(generation_kwh = sum(generation_kwh), .groups = "drop")
    plot <- ggplot(monthly_data, aes(month, generation_kwh, text = paste("Month:", format(month, "%b %Y"), "<br>kWh:", round(generation_kwh, 1)))) +
      geom_col(fill = "#367b55", width = 24) +
      labs(x = NULL, y = "Generation (kWh)") +
      theme_minimal(base_size = 12) +
      theme(panel.grid.minor = element_blank())
    ggplotly(plot, tooltip = "text")
  })

  output$weather_filter_ui <- renderUI({
    available <- intersect(supported_features, names(active_data()$data))
    if (length(available) == 0) {
      return(helpText("No supported weather columns are available in this dataset."))
    }
    selectInput("weather_feature", "Weather feature", choices = stats::setNames(available, feature_labels[available]))
  })

  output$weather_plot <- renderPlotly({
    data <- filtered_data()
    req(input$weather_feature, input$weather_feature %in% names(data))
    data <- data[is.finite(data[[input$weather_feature]]), , drop = FALSE]
    validate(need(nrow(data) > 0, "No numeric observations for this weather feature."))
    feature <- input$weather_feature
    plot <- ggplot(data, aes(x = .data[[feature]], y = generation_kwh,
                             text = paste(feature_labels[[feature]], ":", round(.data[[feature]], 2), "<br>Generation:", round(generation_kwh, 2), "kWh"))) +
      geom_point(color = "#367b55", alpha = 0.7) +
      geom_smooth(method = "lm", formula = y ~ x, se = FALSE, color = "#d29d18", linewidth = 0.8) +
      labs(x = feature_labels[[feature]], y = "Generation (kWh)") +
      theme_minimal(base_size = 12)
    ggplotly(plot, tooltip = "text")
  })

  output$model_notice <- renderUI({
    result <- model_result()
    if (result$ok) {
      div(class = "notice", paste("Model ready. Features:", paste(feature_labels[result$features], collapse = ", "),
                                   ". The earliest 80% of rows train the model; the latest 20% are held out for evaluation."))
    } else {
      div(class = "notice error", result$message)
    }
  })

  output$prediction_inputs <- renderUI({
    result <- model_result()
    if (!result$ok) {
      return(NULL)
    }
    tagList(
      h4(class = "section-title", "Weather inputs"),
      fluidRow(lapply(result$features, function(feature) {
        options <- list(inputId = paste0("feature_", feature), label = feature_labels[[feature]], value = result$medians[[feature]], step = "any")
        if (feature == "cloud_cover") {
          options$min <- 0
          options$max <- 100
        }
        do.call(numericInput, options)
      }))
    )
  })

  prediction_result <- eventReactive(input$predict_button, {
    result <- model_result()
    if (!result$ok) {
      return(list(error = result$message))
    }

    values <- vapply(result$features, function(feature) {
      value <- input[[paste0("feature_", feature)]]
      if (is.null(value) || length(value) != 1 || !is.finite(value)) NA_real_ else value
    }, numeric(1))

    if (any(!is.finite(values))) {
      return(list(error = "Enter a valid finite number for every weather field."))
    }
    if ("cloud_cover" %in% names(values) && (values[["cloud_cover"]] < 0 || values[["cloud_cover"]] > 100)) {
      return(list(error = "Cloud cover must be between 0 and 100 percent."))
    }

    new_weather <- as.data.frame(as.list(values))
    prediction <- tryCatch(as.numeric(predict(result$model, newdata = new_weather)), error = function(error) NA_real_)
    if (length(prediction) != 1 || !is.finite(prediction)) {
      return(list(error = "The model could not produce a finite prediction for these inputs."))
    }

    list(inputs = new_weather, prediction = max(0, prediction), date = Sys.Date())
  })

  output$prediction_result <- renderUI({
    result <- prediction_result()
    if (is.null(result)) {
      return(NULL)
    }
    if (!is.null(result$error)) {
      return(div(class = "notice error", result$error))
    }
    div(class = "metric", div(class = "metric-label", paste("Predicted generation for", format(result$date, "%d %b %Y"))),
        div(class = "metric-value", paste(round(result$prediction, 2), "kWh")))
  })

  output$actual_predicted_plot <- renderPlotly({
    result <- model_result()
    validate(need(result$ok, if (result$ok) "" else result$message))
    comparison <- data.frame(
      date = result$testing$date,
      actual = result$testing$generation_kwh,
      predicted = result$test_predictions
    )
    plot <- ggplot(comparison, aes(actual, predicted, text = paste("Date:", date, "<br>Actual:", round(actual, 2), "kWh<br>Predicted:", round(predicted, 2), "kWh"))) +
      geom_point(color = "#367b55", alpha = 0.8, size = 2) +
      geom_abline(intercept = 0, slope = 1, linetype = "dashed", color = "#d29d18") +
      labs(x = "Actual generation (kWh)", y = "Predicted generation (kWh)") +
      theme_minimal(base_size = 12)
    ggplotly(plot, tooltip = "text")
  })

  output$model_metrics <- renderTable({
    result <- model_result()
    if (!result$ok) {
      return(data.frame(Status = result$message))
    }
    data.frame(
      Metric = c("MAE (kWh)", "RMSE (kWh)", "Training rows", "Test rows"),
      Value = c(round(result$mae, 3), round(result$rmse, 3), nrow(result$training), nrow(result$testing))
    )
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  output$historical_table <- renderTable({
    head(active_data()$data, 200)
  }, striped = TRUE, bordered = TRUE, spacing = "s", rownames = FALSE)

  output$upload_message <- renderUI({
    message <- upload_message()
    if (is.null(message)) {
      return(NULL)
    }
    div(class = if (startsWith(message, "Upload not applied:")) "notice error" else "notice", message)
  })

  output$download_prediction <- downloadHandler(
    filename = function() paste0("solar_prediction_", Sys.Date(), ".csv"),
    content = function(file) {
      result <- prediction_result()
      if (is.null(result) || !is.null(result$error)) {
        write.csv(data.frame(message = if (is.null(result)) "Run a valid prediction first." else result$error), file, row.names = FALSE)
        return()
      }
      output_data <- cbind(data.frame(prediction_date = result$date), result$inputs)
      output_data$predicted_generation_kwh <- result$prediction
      write.csv(output_data, file, row.names = FALSE)
    }
  )

  output$download_summary <- downloadHandler(
    filename = function() paste0("solar_historical_summary_", Sys.Date(), ".csv"),
    content = function(file) {
      data <- active_data()$data
      summary <- data.frame(
        dataset_source = active_data()$source,
        usable_rows = nrow(data),
        first_date = min(data$date),
        last_date = max(data$date),
        total_generation_kwh = sum(data$generation_kwh),
        average_daily_generation_kwh = mean(data$generation_kwh),
        highest_daily_generation_kwh = max(data$generation_kwh)
      )
      write.csv(summary, file, row.names = FALSE)
    }
  )
}

shinyApp(ui = ui, server = server)
