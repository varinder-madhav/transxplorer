# Queue Management System for TransXplorer - IMPROVED VERSION
# With file locking and better error handling

library(digest)

# Queue configuration
MAX_CONCURRENT_JOBS <- 2
QUEUE_CHECK_INTERVAL <- 5
JOB_TIMEOUT_HOURS <- 6 # Kill jobs running longer than this

# Initialize queue directory
initialize_queue_system <- function() {
  QUEUE_DIR <- "/srv/transxplorer/queue"

  # Create main queue directory
  if (!dir.exists(QUEUE_DIR)) {
    dir.create(QUEUE_DIR, showWarnings = FALSE, recursive = TRUE)
  }

  # Create subdirectories for better organization
  for (subdir in c("active", "completed", "failed")) {
    subpath <- file.path(QUEUE_DIR, subdir)
    if (!dir.exists(subpath)) {
      dir.create(subpath, showWarnings = FALSE)
    }
  }

  return(QUEUE_DIR)
}

# Define the path constant but DO NOT create directories immediately
# This prevents blocking the server startup if the filesystem is slow
QUEUE_DIR <- "/srv/transxplorer/queue"

# Helper to ensure directories exist (Lazy Initialization)
ensure_queue_dirs <- function() {
  if (!dir.exists(QUEUE_DIR)) {
    dir.create(QUEUE_DIR, showWarnings = FALSE, recursive = TRUE)
  }
  for (subdir in c("active", "completed", "failed")) {
    subpath <- file.path(QUEUE_DIR, subdir)
    if (!dir.exists(subpath)) {
      dir.create(subpath, showWarnings = FALSE)
    }
  }
}

# File locking helper to prevent race conditions
with_file_lock <- function(lock_file, expr, timeout = 30) {
  # Ensure directories exist before trying to create a lock file
  ensure_queue_dirs()

  lock_path <- file.path(QUEUE_DIR, paste0(lock_file, ".lock"))

  # Try to acquire lock
  start_time <- Sys.time()
  lock_acquired <- FALSE

  while (!lock_acquired && difftime(Sys.time(), start_time, units = "secs") < timeout) {
    if (!file.exists(lock_path)) {
      # Try to create lock file
      tryCatch(
        {
          writeLines(as.character(Sys.getpid()), lock_path)
          lock_acquired <- TRUE
        },
        error = function(e) {
          Sys.sleep(0.1)
        }
      )
    } else {
      # Check if lock is stale (older than 60 seconds)
      lock_age <- difftime(Sys.time(), file.info(lock_path)$mtime, units = "secs")
      if (lock_age > 60) {
        file.remove(lock_path)
      } else {
        Sys.sleep(0.1)
      }
    }
  }

  if (!lock_acquired) {
    stop("Could not acquire file lock within timeout")
  }

  # Execute expression
  result <- tryCatch({
    force(expr)
  }, finally = {
    # Always release lock
    if (file.exists(lock_path)) {
      file.remove(lock_path)
    }
  })

  return(result)
}

# Function to get queue info
get_queue_info <- function() {
  with_file_lock("queue_read", {
    queue_files <- list.files(QUEUE_DIR, pattern = "^job_.*\\.rds$", full.names = TRUE)

    if (length(queue_files) == 0) {
      return(list(
        total_jobs = 0,
        active_jobs = 0,
        queued_jobs = 0,
        queue = data.frame()
      ))
    }

    jobs <- lapply(queue_files, function(f) {
      tryCatch(readRDS(f), error = function(e) NULL)
    })
    jobs <- jobs[!sapply(jobs, is.null)]

    if (length(jobs) == 0) {
      return(list(
        total_jobs = 0,
        active_jobs = 0,
        queued_jobs = 0,
        queue = data.frame()
      ))
    }

    queue_df <- do.call(rbind, lapply(jobs, function(j) {
      data.frame(
        job_id = j$job_id,
        session_id = j$session_id,
        status = j$status,
        submit_time = j$submit_time,
        start_time = if (is.null(j$start_time)) NA else j$start_time,
        stringsAsFactors = FALSE
      )
    }))

    queue_df <- queue_df[order(queue_df$submit_time), ]

    list(
      total_jobs = nrow(queue_df),
      active_jobs = sum(queue_df$status == "processing"),
      queued_jobs = sum(queue_df$status == "queued"),
      queue = queue_df
    )
  })
}

# Add job to queue with duplicate prevention
add_to_queue <- function(session_id, job_data) {
  with_file_lock("queue_write", {
    # Check if this session already has a queued/processing job
    existing <- get_queue_position(session_id)
    if (existing$status %in% c("queued", "processing")) {
      warning("Session already has an active job: ", existing$job_id)
      return(existing$job_id)
    }

    job_id <- paste0(
      "job_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_",
      substr(digest::digest(paste0(session_id, runif(1))), 1, 8)
    )

    job_info <- list(
      job_id = job_id,
      session_id = session_id,
      status = "queued",
      submit_time = Sys.time(),
      start_time = NULL,
      end_time = NULL,
      data = job_data,
      result_path = NULL,
      error = NULL,
      worker_pid = NULL
    )

    job_file <- file.path(QUEUE_DIR, paste0(job_id, ".rds"))
    saveRDS(job_info, job_file)

    cat(format(Sys.time()), "- Job", job_id, "added to queue for session", session_id, "\n")
    return(job_id)
  })
}

# Update job status with validation
update_job_status <- function(job_id, status, result_path = NULL, error = NULL) {
  with_file_lock("queue_write", {
    job_file <- file.path(QUEUE_DIR, paste0(job_id, ".rds"))

    if (!file.exists(job_file)) {
      warning("Job file not found: ", job_id)
      return(FALSE)
    }

    job_info <- readRDS(job_file)
    old_status <- job_info$status
    job_info$status <- status

    if (status == "processing" && is.null(job_info$start_time)) {
      job_info$start_time <- Sys.time()
      job_info$worker_pid <- Sys.getpid()
    }

    if (status %in% c("complete", "error")) {
      job_info$end_time <- Sys.time()

      # Move to appropriate subdirectory
      target_dir <- if (status == "complete") "completed" else "failed"
      target_path <- file.path(QUEUE_DIR, target_dir, paste0(job_id, ".rds"))

      saveRDS(job_info, target_path)
      file.remove(job_file)

      cat(format(Sys.time()), "- Job", job_id, "moved to", target_dir, "\n")
      return(TRUE)
    }

    if (!is.null(result_path)) {
      job_info$result_path <- result_path
    }

    if (!is.null(error)) {
      job_info$error <- error
    }

    saveRDS(job_info, job_file)
    cat(format(Sys.time()), "- Job", job_id, "status changed:", old_status, "->", status, "\n")
    return(TRUE)
  })
}

# Get queue position
get_queue_position <- function(session_id) {
  queue_info <- get_queue_info()

  if (queue_info$total_jobs == 0) {
    return(list(position = 0, status = "ready"))
  }

  user_jobs <- queue_info$queue[queue_info$queue$session_id == session_id, ]

  if (nrow(user_jobs) == 0) {
    return(list(position = 0, status = "ready"))
  }

  latest_job <- user_jobs[order(user_jobs$submit_time, decreasing = TRUE), ][1, ]

  if (latest_job$status == "processing") {
    # Calculate elapsed time
    elapsed <- if (!is.na(latest_job$start_time)) {
      round(difftime(Sys.time(), latest_job$start_time, units = "mins"), 1)
    } else {
      0
    }

    return(list(
      position = 0,
      status = "processing",
      job_id = latest_job$job_id,
      elapsed_minutes = elapsed
    ))
  }

  if (latest_job$status == "queued") {
    queued_before <- sum(
      queue_info$queue$status == "queued" &
        queue_info$queue$submit_time < latest_job$submit_time
    )

    return(list(
      position = queued_before + 1,
      status = "queued",
      job_id = latest_job$job_id,
      active_jobs = queue_info$active_jobs
    ))
  }

  return(list(
    position = 0,
    status = latest_job$status,
    job_id = latest_job$job_id
  ))
}

# Process queue with timeout checking
process_queue <- function() {
  with_file_lock("queue_process", {
    queue_info <- get_queue_info()

    # Check for timed-out jobs
    if (queue_info$active_jobs > 0) {
      active <- queue_info$queue[queue_info$queue$status == "processing", ]
      for (i in seq_len(nrow(active))) {
        if (!is.na(active$start_time[i])) {
          elapsed <- difftime(Sys.time(), active$start_time[i], units = "hours")
          if (elapsed > JOB_TIMEOUT_HOURS) {
            cat(
              format(Sys.time()), "- Job", active$job_id[i], "timed out after",
              round(elapsed, 1), "hours\n"
            )
            update_job_status(active$job_id[i], "error",
              error = paste("Job timed out after", JOB_TIMEOUT_HOURS, "hours")
            )
            queue_info$active_jobs <- queue_info$active_jobs - 1
          }
        }
      }
    }

    if (queue_info$active_jobs >= MAX_CONCURRENT_JOBS) {
      return(NULL)
    }

    queued_jobs <- queue_info$queue[queue_info$queue$status == "queued", ]

    if (nrow(queued_jobs) == 0) {
      return(NULL)
    }

    next_job <- queued_jobs[order(queued_jobs$submit_time), ][1, ]
    update_job_status(next_job$job_id, "processing")

    cat(format(Sys.time()), "- Starting job:", next_job$job_id, "\n")
    return(next_job$job_id)
  })
}

# Clean up old jobs - call this periodically
cleanup_old_jobs <- function(max_age_hours = 24) {
  for (subdir in c("completed", "failed")) {
    dir_path <- file.path(QUEUE_DIR, subdir)
    if (!dir.exists(dir_path)) next

    files <- list.files(dir_path, pattern = "\\.rds$", full.names = TRUE)

    for (f in files) {
      age <- difftime(Sys.time(), file.info(f)$mtime, units = "hours")
      if (age > max_age_hours) {
        file.remove(f)
        cat(format(Sys.time()), "- Cleaned up old job file:", basename(f), "\n")
      }
    }
  }

  # Also clean up any stale lock files
  lock_files <- list.files(QUEUE_DIR, pattern = "\\.lock$", full.names = TRUE)
  for (lf in lock_files) {
    age <- difftime(Sys.time(), file.info(lf)$mtime, units = "secs")
    if (age > 120) { # 2 minutes old
      file.remove(lf)
    }
  }
}

# MAIN INITIALIZATION FUNCTION - Call this from server()
initialize_queue_ui <- function(output, session, queue_status) {
  # Queue status UI output - reduced polling frequency
  output$queue_status_ui <- renderUI({
    # Only poll every 10 seconds instead of 5
    invalidateLater(10000, session)

    position_info <- tryCatch(
      {
        get_queue_position(queue_status$session_id)
      },
      error = function(e) {
        list(position = 0, status = "ready")
      }
    )

    if (position_info$status == "ready") {
      return(
        div(
          class = "alert alert-success",
          style = "margin: 10px 0;",
          icon("check-circle"), " System ready - you can start your analysis"
        )
      )
    }

    if (position_info$status == "processing") {
      elapsed_text <- if (!is.null(position_info$elapsed_minutes)) {
        paste0(" (", position_info$elapsed_minutes, " min elapsed)")
      } else {
        ""
      }

      return(
        div(
          class = "alert alert-info",
          style = "margin: 10px 0;",
          icon("spinner", class = "fa-spin"),
          " Your analysis is currently processing...", elapsed_text,
          br(),
          tags$small("Job ID: ", code(position_info$job_id))
        )
      )
    }

    if (position_info$status == "queued") {
      est_wait <- position_info$position * 20 # ~20 min per job estimate

      return(
        div(
          class = "alert alert-warning",
          style = "margin: 10px 0;",
          icon("clock"),
          sprintf(" Position #%d in queue", position_info$position),
          br(),
          sprintf("Active jobs: %d / %d", position_info$active_jobs, MAX_CONCURRENT_JOBS),
          br(),
          tags$small("Job ID: ", code(position_info$job_id)),
          br(),
          tags$small(
            class = "text-muted",
            sprintf("Estimated wait: ~%d minutes", est_wait)
          )
        )
      )
    }

    if (position_info$status == "complete") {
      return(
        div(
          class = "alert alert-success",
          style = "margin: 10px 0;",
          icon("check"), " Analysis complete! Results are ready."
        )
      )
    }

    if (position_info$status == "error") {
      return(
        div(
          class = "alert alert-danger",
          style = "margin: 10px 0;",
          icon("exclamation-triangle"),
          " Analysis encountered an error. Please check your input files and try again.",
          br(),
          tags$small("You can submit a new job.")
        )
      )
    }
  })

  # Clean up old jobs periodically (every 2 hours)
  observe({
    invalidateLater(7200000, session) # 2 hours
    cleanup_old_jobs(max_age_hours = 48)
  })
}

# Return list of functions to use in main app
list(
  initialize_queue_ui = initialize_queue_ui,
  get_queue_info = get_queue_info,
  add_to_queue = add_to_queue,
  update_job_status = update_job_status,
  get_queue_position = get_queue_position,
  process_queue = process_queue,
  cleanup_old_jobs = cleanup_old_jobs,
  MAX_CONCURRENT_JOBS = MAX_CONCURRENT_JOBS,
  QUEUE_DIR = QUEUE_DIR
)
