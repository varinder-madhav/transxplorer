/* TransXplorer resumable FASTQ uploads (tus protocol via Uppy).
 *
 * The browser streams files to tusd in chunks; a dropped connection or a closed
 * laptop resumes from the last byte the server stored. Shiny only hears about
 * state changes (file added / finished / failed) and a throttled progress
 * summary, so a 40 GB upload never floods the websocket.
 *
 * Shiny inputs set here:
 *   tx_upload_hello  {token}            ask the server for an upload token
 *   tx_upload_state  {total, active, failed, pct, bytes}   throttled summary
 *   tx_upload_done   {name, id}          a file finished uploading (event)
 * Shiny messages handled:
 *   tx_upload_init   {token}            token to attach to every upload
 *   tx_upload_reset  {}                 files were handed to a job; clear the widget
 */
(function () {
  'use strict';

  var UPPY_VERSION = '4.18.3';
  var TOKEN_KEY = 'tx_upload_token';
  var MAX_BYTES = 40 * 1024 * 1024 * 1024;
  var NAME_RE = /^[A-Za-z0-9._-]+\.(fastq|fq)(\.gz)?$/i;

  var uppy = null;
  var assets = null;
  var token = null;
  var helloSent = false;
  var panelShown = false;

  // Start button: show progress the moment it is clicked (the server may need a few
  // seconds before the job starts); txRunRestore() undoes it if validation fails.
  window.txRunPressed = function (btn) {
    if (btn.classList.contains('btn-disabled-running')) return;
    btn.dataset.originalHtml = btn.innerHTML;
    btn.innerHTML = '<i class="fa fa-spinner fa-spin" style="margin-right:6px;"></i> Starting analysis...';
    btn.classList.add('btn-disabled-running');
    setTimeout(function () { btn.disabled = true; }, 0);
  };
  window.txRunRestore = function () {
    var btn = document.getElementById('run_processing');
    if (!btn || !btn.dataset.originalHtml) return;
    btn.innerHTML = btn.dataset.originalHtml;
    delete btn.dataset.originalHtml;
    btn.classList.remove('btn-disabled-running');
    btn.disabled = false;
  };

  function endpoint() {
    // The development container is reached directly on port 3839 (SSH tunnel);
    // tusd then listens on port 1080 of the same host. Production goes through nginx.
    if (window.location.port === '3839') {
      return window.location.protocol + '//' + window.location.hostname + ':1080/tus/files/';
    }
    return '/tus/files/';
  }

  function loadAssets() {
    if (assets) return assets;
    assets = new Promise(function (resolve, reject) {
      var css = document.createElement('link');
      css.rel = 'stylesheet';
      css.href = 'uppy/uppy.min.css?v=' + UPPY_VERSION;
      document.head.appendChild(css);
      var js = document.createElement('script');
      js.src = 'uppy/uppy.min.js?v=' + UPPY_VERSION;
      js.onload = function () { resolve(window.Uppy); };
      js.onerror = function () { assets = null; reject(new Error('Upload component failed to load')); };
      document.head.appendChild(js);
    });
    return assets;
  }

  function storedToken() {
    try { return window.localStorage.getItem(TOKEN_KEY) || ''; } catch (e) { return ''; }
  }
  function storeToken(t) {
    try { window.localStorage.setItem(TOKEN_KEY, t); } catch (e) { /* private window: token lives for this page only */ }
  }

  function sayHello() {
    if (helloSent || !window.Shiny || !Shiny.setInputValue) return;
    helloSent = true;
    Shiny.setInputValue('tx_upload_hello', { token: storedToken(), n: Date.now() }, { priority: 'event' });
  }

  // ---- throttled summary for the Start button --------------------------------
  var lastSent = 0, pending = null;
  function summary() {
    var files = uppy ? uppy.getFiles() : [];
    var active = 0, failed = 0, total = 0, done = 0;
    files.forEach(function (f) {
      total += f.size || 0;
      if (f.error) failed++;
      else if (!(f.progress && f.progress.uploadComplete)) active++;
      done += (f.progress && f.progress.bytesUploaded) || 0;
    });
    return { files: files.length, active: active, failed: failed,
             pct: total > 0 ? Math.floor(100 * done / total) : 0, bytes: total };
  }
  function pushState(immediate) {
    if (!window.Shiny || !Shiny.setInputValue) return;
    var now = Date.now();
    var send = function () {
      lastSent = Date.now(); pending = null;
      Shiny.setInputValue('tx_upload_state', summary());
    };
    if (immediate || now - lastSent > 1500) { if (pending) clearTimeout(pending); send(); }
    else if (!pending) pending = setTimeout(send, 1500 - (now - lastSent));
  }

  function build(U) {
    var target = document.getElementById('tx-uppy');
    if (!target || uppy) return;

    uppy = new U.Uppy({
      id: 'tx-fastq',
      autoProceed: true,
      allowMultipleUploadBatches: true,
      restrictions: { maxFileSize: MAX_BYTES },
      meta: { token: token },
      onBeforeFileAdded: function (file) {
        if (!NAME_RE.test(file.name)) {
          uppy.info('"' + file.name + '" was not added: use FASTQ files (.fastq, .fq, .fastq.gz, .fq.gz) ' +
                    'whose names contain only letters, digits, dot, dash or underscore.', 'error', 8000);
          return false;
        }
        return true;
      },
      locale: { strings: { youCanOnlyUploadFileTypes: 'Only FASTQ files can be uploaded' } }
    });

    uppy.use(U.Dashboard, {
      inline: true,
      target: target,
      width: '100%',
      height: 320,
      showProgressDetails: true,
      proudlyDisplayPoweredByUppy: false,
      hideCancelButton: false,
      hidePauseResumeButton: false,
      hideRetryButton: false,
      showRemoveButtonAfterComplete: false,
      fileManagerSelectionType: 'files',
      note: 'FASTQ (.fastq, .fq, .fastq.gz, .fq.gz), up to 40 GB in total. ' +
            'Uploads resume automatically after a dropped connection; after closing the page, add the same files again to continue.',
      locale: { strings: {
        dropPasteFiles: 'Drop FASTQ files here or %{browseFiles}',
        browseFiles: 'browse'
      } }
    });

    uppy.use(U.Tus, {
      endpoint: endpoint(),
      chunkSize: 128 * 1024 * 1024,       // bounded requests: a broken one loses at most one chunk
      limit: 3,                             // three files in parallel
      retryDelays: [0, 1000, 3000, 5000, 10000, 20000, 30000, 60000, 60000, 120000, 120000, 300000],
      removeFingerprintOnSuccess: true,
      onShouldRetry: function (err, retryAttempt, options, next) {
        var status = err && err.originalResponse ? err.originalResponse.getStatus() : 0;
        if (status === 400 || status === 403 || status === 413 || status === 507) return false; // rejected by the server: retrying won't help
        return next(err);
      }
    });

    if (U.GoldenRetriever) uppy.use(U.GoldenRetriever, { serviceWorker: false });

    uppy.on('file-added', function () { pushState(true); });
    uppy.on('file-removed', function () { pushState(true); });
    uppy.on('upload-progress', function () { pushState(false); });
    uppy.on('upload-error', function (file, err, response) {
      var body = response && response.body ? response.body : '';
      var msg = (err && err.originalResponse && err.originalResponse.getBody && err.originalResponse.getBody()) || body || '';
      if (msg) uppy.info(file.name + ': ' + String(msg).slice(0, 300), 'error', 10000);
      pushState(true);
    });
    uppy.on('upload-success', function (file) {
      var url = file && file.tus && file.tus.uploadUrl ? file.tus.uploadUrl : (file.uploadURL || '');
      var id = url.split('/').filter(Boolean).pop() || '';
      Shiny.setInputValue('tx_upload_done', { name: file.name, id: id, n: Date.now() }, { priority: 'event' });
      // Finished files move to the "ready on the server" list rendered by Shiny.
      setTimeout(function () { try { uppy.removeFile(file.id); } catch (e) { /* already gone */ } }, 1200);
    });
    uppy.on('complete', function () { pushState(true); });
    uppy.on('restore-confirmed', function () { pushState(true); });

    window.addEventListener('beforeunload', function (e) {
      if (uppy && summary().active > 0) { e.preventDefault(); e.returnValue = ''; }
    });

    pushState(true);
  }

  function start() {
    loadAssets().then(build).catch(function (err) {
      var target = document.getElementById('tx-uppy');
      if (target) target.innerHTML = '<div class="tx-upload-error">The upload component could not be loaded (' +
        err.message + '). Please reload the page.</div>';
    });
  }

  // The token is requested as soon as Shiny connects; the upload component itself
  // (575 KB) is only fetched once the FASTQ panel is shown.
  function maybeStart() { if (token && panelShown && !uppy) start(); }
  function showPanel() { panelShown = true; loadAssets().catch(function () {}); maybeStart(); }

  function whenVisible() {
    var target = document.getElementById('tx-uppy');
    if (!target) return false;
    if (!('IntersectionObserver' in window)) { showPanel(); return true; }
    var io = new IntersectionObserver(function (entries) {
      if (entries.some(function (e) { return e.isIntersecting; })) { io.disconnect(); showPanel(); }
    }, { rootMargin: '0px 0px 4000px 0px' });   // fires once the FASTQ panel is shown, even below the fold
    io.observe(target);
    return true;
  }

  // After a reconnect the server is a new session: ask for the token again
  $(document).on('shiny:disconnected', function () { helloSent = false; });

  $(document).on('shiny:connected', function () {
    if (window.Shiny && Shiny.addCustomMessageHandler) {
      Shiny.addCustomMessageHandler('tx_upload_init', function (msg) {
        token = msg.token;
        storeToken(token);
        if (uppy) uppy.setMeta({ token: token }); else maybeStart();
      });
      Shiny.addCustomMessageHandler('tx_upload_reset', function (msg) {
        if (!uppy) return;
        uppy.getFiles().forEach(function (f) {
          if (f.progress && f.progress.uploadComplete) { try { uppy.removeFile(f.id); } catch (e) {} }
        });
        pushState(true);
      });
    }
    sayHello();
    if (!whenVisible()) {
      // The FASTQ panel is rendered later; watch for it once.
      var mo = new MutationObserver(function () { if (whenVisible()) mo.disconnect(); });
      mo.observe(document.body, { childList: true, subtree: true });
    }
  });
})();
