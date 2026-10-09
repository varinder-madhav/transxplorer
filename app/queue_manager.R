# Queue for TransXplorer FASTQ jobs.
#
# Each job is one RDS record in QUEUE_DIR:
#   queued      waiting for a processing slot; its parameters are saved in its job folder
#   processing  a background R process runs it (pid + process start time recorded)
#   complete / error  record moved to completed/ or failed/
#
# Every change is made under one lock (an atomic mkdir), and records are written to a temporary
# file and renamed, so a reader never sees a half-written record. Jobs do not depend on the
# browser: a queued job is started by whichever app process next calls process_queue() (the app
# runs it every few seconds), and a job whose process has died is detected and its slot freed.

library(digest)

MAX_CONCURRENT_JOBS <- as.integer(Sys.getenv("TX_MAX_JOBS", "3"))
JOB_TIMEOUT_HOURS <- 48
QUEUE_DIR <- Sys.getenv("TX_QUEUE_DIR", "/srv/transxplorer/queue")

ensure_queue_dirs <- function() {
  for (d in c(QUEUE_DIR, file.path(QUEUE_DIR, c("completed", "failed"))))
    if (!dir.exists(d)) dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

# ---- locking ------------------------------------------------------------------------------
# mkdir succeeds for exactly one process. A lock older than 2 minutes belongs to a process
# that died while holding it. Re-entrant within one R process (R is single-threaded).
.queue_lock <- new.env(parent = emptyenv())
.queue_lock$depth <- 0L

with_queue_lock <- function(expr, timeout = 30) {
  if (.queue_lock$depth > 0L) return(force(expr))
  ensure_queue_dirs()
  lock <- file.path(QUEUE_DIR, "queue.lock")
  start <- Sys.time()
  repeat {
    if (dir.create(lock, showWarnings = FALSE)) break
    age <- difftime(Sys.time(), file.mtime(lock), units = "secs")
    if (!is.na(age) && age > 120) { unlink(lock, recursive = TRUE); next }
    if (difftime(Sys.time(), start, units = "secs") > timeout) stop("Could not acquire the queue lock")
    Sys.sleep(0.05)
  }
  .queue_lock$depth <- 1L
  on.exit({ .queue_lock$depth <- 0L; unlink(lock, recursive = TRUE) }, add = TRUE)
  force(expr)
}

# ---- records ------------------------------------------------------------------------------
job_path <- function(job_id, sub = NULL) {
  if (is.null(sub)) file.path(QUEUE_DIR, paste0(job_id, ".rds")) else file.path(QUEUE_DIR, sub, paste0(job_id, ".rds"))
}

write_job <- function(job, sub = NULL) {
  path <- job_path(job$job_id, sub)
  tmp <- paste0(path, ".tmp", Sys.getpid())
  saveRDS(job, tmp)
  file.rename(tmp, path)
}

read_job <- function(job_id) {
  for (sub in list(NULL, "completed", "failed")) {
    f <- job_path(job_id, sub)
    if (file.exists(f)) return(tryCatch(readRDS(f), error = function(e) NULL))
  }
  NULL
}

# Queued and running jobs, oldest first
read_active_jobs <- function() {
  files <- list.files(QUEUE_DIR, pattern = "^job_.*\\.rds$", full.names = TRUE)
  jobs <- Filter(Negate(is.null), lapply(files, function(f) tryCatch(readRDS(f), error = function(e) NULL)))
  if (length(jobs) == 0) return(list())
  jobs[order(vapply(jobs, function(j) as.numeric(j$submit_time), 0))]
}

# ---- processes ----------------------------------------------------------------------------
# A process is identified by pid + start time (field 22 of /proc/<pid>/stat), so a recycled
# pid is never mistaken for the job. A zombie (finished, not yet reaped) counts as ended.
proc_info <- function(pid) {
  if (is.null(pid) || is.na(pid)) return(NULL)
  x <- tryCatch(suppressWarnings(readLines(sprintf("/proc/%d/stat", as.integer(pid)), warn = FALSE)), error = function(e) NULL)
  if (length(x) == 0) return(NULL)
  f <- strsplit(sub("^.*\\) ", "", x[1]), " ")[[1]]   # fields from 3 (state) onwards
  list(state = f[1], start = f[20])
}

job_alive <- function(job) {
  p <- proc_info(job$pid)
  !is.null(p) && identical(p$start, job$pid_start) && p$state != "Z"
}

kill_job <- function(job) {
  pid <- as.integer(job$pid)
  tab <- tryCatch(read.table(text = system("ps -eo pid=,ppid=", intern = TRUE), col.names = c("pid", "ppid")),
                  error = function(e) data.frame(pid = integer(0), ppid = integer(0)))
  tree <- pid
  repeat {
    kids <- setdiff(tab$pid[tab$ppid %in% tree], tree)
    if (length(kids) == 0) break
    tree <- c(tree, kids)
  }
  tools::pskill(rev(tree), tools::SIGTERM)
}

job_completion <- function(job) {
  f <- if (!is.null(job$job_dir)) file.path(job$job_dir, "completion.rds") else ""
  if (nzchar(f) && file.exists(f)) tryCatch(readRDS(f), error = function(e) NULL) else NULL
}

# Close a job: move its record to completed/ or failed/. A job that ended without reporting
# (its process was killed) gets an error result in its folder, so the page and "Retrieve
# results by job ID" show the failure instead of waiting forever.
finish_job <- function(job, status, error = NULL) {
  job$status <- status
  job$end_time <- Sys.time()
  if (!is.null(error)) job$error <- error
  if (status == "error" && !is.null(job$job_dir) && dir.exists(job$job_dir) && is.null(job_completion(job))) {
    msg <- job$error %||% "The job stopped unexpectedly"
    try(saveRDS(list(success = FALSE, error = msg, job_id = job$job_id), file.path(job$job_dir, "completion.rds")), silent = TRUE)
    try(writeLines(paste0("0|Error: ", msg), file.path(job$job_dir, "progress.txt")), silent = TRUE)
    try(cat(format(Sys.time(), "[%H:%M:%S]"), "[ERROR]", msg, "\n", file = file.path(job$job_dir, "log.txt"), append = TRUE), silent = TRUE)
  }
  write_job(job, if (status == "complete") "completed" else "failed")
  unlink(job_path(job$job_id))
  cat(format(Sys.time()), "- Job", job$job_id, status, if (!is.null(error)) paste0("(", error, ")"), "\n")
  invisible(TRUE)
}

# Free the slots of jobs whose process has ended or run too long
reap_jobs <- function() {
  for (j in read_active_jobs()) {
    if (!identical(j$status, "processing")) next
    if (job_alive(j)) {
      if (difftime(Sys.time(), j$start_time, units = "hours") > JOB_TIMEOUT_HOURS) {
        kill_job(j)
        finish_job(j, "error", sprintf("Stopped after running for more than %d hours", JOB_TIMEOUT_HOURS))
      }
      next
    }
    # Being launched right now (no pid recorded yet): give it a moment
    if (is.null(j$pid) && difftime(Sys.time(), j$start_time, units = "mins") < 2) next
    res <- job_completion(j)
    if (isTRUE(res$success)) finish_job(j, "complete")
    else finish_job(j, "error", res$error %||% "The job stopped unexpectedly (for example, the server restarted). Please submit it again.")
  }
}

# ---- public API ---------------------------------------------------------------------------

# Register a job. Its parameters must already be saved in job_dir/params.rds.
# Call process_queue() afterwards: it starts the job at once if a slot is free.
submit_job <- function(job_id, session_id, job_dir, data = list()) {
  with_queue_lock({
    write_job(list(job_id = job_id, session_id = session_id, job_dir = job_dir, status = "queued",
                   submit_time = Sys.time(), start_time = NULL, end_time = NULL, data = data,
                   pid = NULL, pid_start = NULL, error = NULL))
    cat(format(Sys.time()), "- Job", job_id, "submitted\n")
    job_id
  })
}

# Start queued jobs (oldest first) while slots are free. `launch(job)` starts the job's
# background process and returns its pid. Returns the ids of the jobs started.
process_queue <- function(launch) {
  with_queue_lock({
    reap_jobs()
    jobs <- read_active_jobs()
    running <- sum(vapply(jobs, function(j) identical(j$status, "processing"), TRUE))
    started <- character(0)
    for (j in jobs) {
      if (running >= MAX_CONCURRENT_JOBS) break
      if (!identical(j$status, "queued")) next
      j$status <- "processing"
      j$start_time <- Sys.time()
      write_job(j)
      pid <- tryCatch(launch(j), error = function(e) e)
      if (inherits(pid, "error")) {
        finish_job(j, "error", paste("Could not start the job:", conditionMessage(pid)))
        next
      }
      j$pid <- as.integer(pid)
      j$pid_start <- proc_info(pid)$start
      write_job(j)
      running <- running + 1
      started <- c(started, j$job_id)
      cat(format(Sys.time()), "- Job", j$job_id, "started (pid", pid, ")\n")
    }
    started
  })
}

# Called by a job's own process when it finishes (and kept for older callers)
update_job_status <- function(job_id, status, result_path = NULL, error = NULL) {
  with_queue_lock({
    f <- job_path(job_id)
    if (!file.exists(f)) return(FALSE)
    j <- readRDS(f)
    if (status %in% c("complete", "error")) return(finish_job(j, status, error))
    j$status <- status
    if (!is.null(result_path)) j$result_path <- result_path
    write_job(j)
    TRUE
  })
}

get_queue_info <- function() {
  jobs <- read_active_jobs()
  st <- vapply(jobs, function(j) j$status, "")
  list(total_jobs = length(jobs), active_jobs = sum(st == "processing"), queued_jobs = sum(st == "queued"))
}

# Where a job stands: status, place in the queue, minutes running
job_queue_state <- function(job_id) {
  if (is.null(job_id)) return(list(status = "none"))
  jobs <- read_active_jobs()
  ids <- vapply(jobs, function(j) j$job_id, "")
  k <- match(job_id, ids)
  running <- sum(vapply(jobs, function(j) identical(j$status, "processing"), TRUE))
  if (is.na(k)) {
    j <- read_job(job_id)
    return(list(status = if (is.null(j)) "none" else j$status, error = j$error))
  }
  j <- jobs[[k]]
  if (j$status == "queued") {
    ahead <- sum(vapply(jobs[seq_len(k - 1)], function(x) identical(x$status, "queued"), TRUE))
    return(list(status = "queued", position = ahead + 1, active_jobs = running))
  }
  list(status = j$status, active_jobs = running,
       elapsed_minutes = round(as.numeric(difftime(Sys.time(), j$start_time, units = "mins"))))
}

cleanup_old_jobs <- function(max_age_days = 30) {
  for (sub in c("completed", "failed")) {
    for (f in list.files(file.path(QUEUE_DIR, sub), pattern = "\\.rds$", full.names = TRUE))
      if (difftime(Sys.time(), file.mtime(f), units = "days") > max_age_days) unlink(f)
  }
  for (f in list.files(QUEUE_DIR, pattern = "\\.tmp[0-9]+$", full.names = TRUE, recursive = TRUE))
    if (difftime(Sys.time(), file.mtime(f), units = "hours") > 1) unlink(f)
}

# Status banner on the FASTQ page. `job_id` is a reactive holding this page's job (or NULL).
# Polls only while that job is queued or running.
initialize_queue_ui <- function(output, session, job_id) {
  output$queue_status_ui <- renderUI({
    jid <- job_id()
    st <- tryCatch(job_queue_state(jid), error = function(e) list(status = "none"))
    if (st$status %in% c("queued", "processing")) invalidateLater(5000, session)

    if (st$status == "queued") {
      return(div(class = "alert alert-warning", style = "margin: 10px 0;",
                 icon("clock"), sprintf(" Waiting for a processing slot: position %d in the queue (%d of %d slots busy).",
                                        st$position, st$active_jobs, MAX_CONCURRENT_JOBS),
                 br(), tags$small("Job ID: ", code(jid), " - you can close this page; the job starts on its own. ",
                                  "Use \"Retrieve results by job ID\" to collect the results later.")))
    }
    if (st$status == "processing") {
      return(div(class = "alert alert-info", style = "margin: 10px 0;",
                 icon("spinner", class = "fa-spin"), sprintf(" Your analysis is running (%d min so far).", st$elapsed_minutes),
                 br(), tags$small("Job ID: ", code(jid), " - you can close this page; the job keeps running.")))
    }
    if (!is.null(jid)) return(NULL)   # finished: the results or the error are shown below

    info <- tryCatch(get_queue_info(), error = function(e) NULL)
    if (is.null(info)) return(NULL)
    free <- max(0, MAX_CONCURRENT_JOBS - info$active_jobs)
    if (free > 0) {
      div(class = "alert alert-success", style = "margin: 10px 0;", icon("check-circle"),
          sprintf(" Server ready: %d of %d processing slots free.", free, MAX_CONCURRENT_JOBS))
    } else {
      div(class = "alert alert-warning", style = "margin: 10px 0;", icon("clock"),
          sprintf(" All %d processing slots are busy (%d job%s waiting). New jobs are queued and start automatically.",
                  MAX_CONCURRENT_JOBS, info$queued_jobs, if (info$queued_jobs == 1) "" else "s"))
    }
  })
}

list(
  initialize_queue_ui = initialize_queue_ui,
  get_queue_info = get_queue_info,
  submit_job = submit_job,
  update_job_status = update_job_status,
  job_queue_state = job_queue_state,
  process_queue = process_queue,
  cleanup_old_jobs = cleanup_old_jobs,
  MAX_CONCURRENT_JOBS = MAX_CONCURRENT_JOBS,
  QUEUE_DIR = QUEUE_DIR
)
