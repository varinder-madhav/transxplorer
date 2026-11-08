/*
 * TransXplorer: explain a closed connection to the visitor.
 *
 * - The server sends "tx_crash" with a report ID when an error in the app's own code ends the
 *   session (the report is already saved and e-mailed); we show what happened and that ID.
 * - The server sends "tx_idle" before closing a session that had no activity for an hour; the
 *   visitor is warned 5 minutes ahead and can stay, and a closed idle page is not reported.
 * - Any other lost connection (server restart, an app process stopped, network drop) shows a
 *   general message, and is remembered in localStorage so it can be reported to the server the next
 *   time the page connects.
 * Either way the visitor is asked to refresh, because a Shiny session cannot resume. FASTQ uploads
 * are not part of the session (www/tx-upload.js), so the message says they are safe.
 */
(function () {
  var crashId = null, idleClosed = false, idleMinutes = 60, unloading = false, shown = false, shownKind = null;

  function activeTab() {
    var a = document.querySelector('.navbar .nav > li.active > a, .navbar .nav-link.active');
    return a ? a.textContent.trim().slice(0, 60) : '';
  }

  // ---- activity heartbeat for the idle timeout ---------------------------------------------
  // At most one message a minute while the visitor uses the page or an upload is running
  // (window.txUploadActive is kept by tx-upload.js); immediately once the idle warning shows.
  var lastActivity = 0, warning = null;
  function activity() {
    var now = Date.now();
    if (!warning && now - lastActivity < 60000) return;
    lastActivity = now;
    if (window.Shiny && Shiny.setInputValue) Shiny.setInputValue('tx_activity', now);
  }
  ['mousemove', 'mousedown', 'keydown', 'wheel', 'scroll', 'touchstart'].forEach(function (ev) {
    document.addEventListener(ev, activity, { passive: true, capture: true });
  });
  setInterval(function () { if (window.txUploadActive > 0) activity(); }, 60000);

  function showIdleWarning(minutes) {
    if (warning) return;
    warning = document.createElement('div');
    warning.id = 'tx-idle-warning';
    warning.setAttribute('role', 'alert');
    warning.innerHTML = '<span>This page has had no activity for ' + (minutes - 5) + ' minutes and will close in ' +
      '5 minutes to free server memory.</span><button type="button" class="tx-conn-btn">Stay connected</button>';
    document.body.appendChild(warning);
    warning.querySelector('button').addEventListener('click', activity);
  }
  function hideIdleWarning() {
    if (warning) { warning.remove(); warning = null; }
  }

  // ---- the message card -----------------------------------------------------------------------
  function show(kind) {
    if (shown) { if (kind === 'crash') fill(kind); return; }
    shown = true; shownKind = kind;
    hideIdleWarning();
    var wrap = document.createElement('div');
    wrap.id = 'tx-conn-overlay';
    wrap.setAttribute('role', 'alertdialog');
    wrap.setAttribute('aria-modal', 'true');
    wrap.setAttribute('aria-labelledby', 'tx-conn-title');
    wrap.innerHTML =
      '<div class="tx-conn-card">' +
      '<div class="tx-conn-icon" aria-hidden="true"></div>' +
      '<h2 id="tx-conn-title"></h2><div class="tx-conn-body"></div>' +
      '<button type="button" class="tx-conn-btn">Refresh the page</button>' +
      '</div>';
    document.body.appendChild(wrap);
    wrap.querySelector('.tx-conn-btn').addEventListener('click', function () { location.reload(); });
    fill(kind);
    wrap.querySelector('.tx-conn-btn').focus();
  }

  function uploadNote() {
    var active = window.txUploadActive || 0, files = (window.txUploadFiles || 0) + (window.txUploadDone || 0);
    if (active > 0)
      return '<p class="tx-conn-sent">Your FASTQ uploads are not affected and keep going in this page. Refresh once ' +
        'they have finished: finished files are listed again after a refresh. If you refresh earlier, add the ' +
        'same files again and they continue where they stopped.</p>';
    if (files > 0)
      return '<p class="tx-conn-sent">Your uploaded FASTQ files are kept and are listed again after you refresh.</p>';
    return '';
  }

  function fill(kind) {
    var w = document.getElementById('tx-conn-overlay');
    if (!w) return;
    w.className = 'tx-conn-' + kind; shownKind = kind;
    var t = w.querySelector('#tx-conn-title'), b = w.querySelector('.tx-conn-body');
    var uploads = uploadNote();
    var reload = '<p>Please <strong>refresh the page</strong> to continue. ' + (uploads ? 'Other data' : 'Data') +
      ' you loaded and results from this visit are not kept after a refresh, so you will need to load them again' +
      ' (unless you saved your session).</p>';
    if (kind === 'crash') {
      t.textContent = 'Something went wrong on our side';
      b.innerHTML =
        '<p>TransXplorer ran into an error in its own code. This was not caused by your data or settings.</p>' +
        '<p class="tx-conn-sent">An error report has been saved and sent to the TransXplorer team' +
        (crashId ? ' (report <code>' + crashId + '</code>)' : '') + '.</p>' + reload + uploads +
        '<p class="tx-conn-small">If the same step fails again, try other settings, or tell us what you were ' +
        'doing with <em>Send feedback</em> at the bottom of the page' +
        (crashId ? ' and mention the report number' : '') + '.</p>';
    } else if (kind === 'idle') {
      t.textContent = 'This page was closed after ' + idleMinutes + ' minutes without activity';
      b.innerHTML =
        '<p>Nothing went wrong: pages that are not used for ' + idleMinutes + ' minutes are closed to free server ' +
        'memory for other visitors.</p>' + reload + uploads;
    } else {
      t.textContent = 'Connection to the server was lost';
      b.innerHTML =
        '<p>This can happen while the server restarts, when an analysis needs more memory than the server ' +
        'allows, or when your internet connection drops.</p>' + reload + uploads +
        '<p class="tx-conn-small">When you refresh, a short report of this disconnection is sent to the ' +
        'TransXplorer team automatically.</p>';
    }
  }

  function register() {
    Shiny.addCustomMessageHandler('tx_crash', function (m) { crashId = m && m.id; show('crash'); });
    Shiny.addCustomMessageHandler('tx_idle', function (m) {
      if (m && m.minutes) idleMinutes = m.minutes;
      if (m && m.state === 'warn') showIdleWarning(idleMinutes);
      else if (m && m.state === 'active') hideIdleWarning();
      else if (m && m.state === 'closed') idleClosed = true;
    });
  }
  // tx-upload.js calls this as uploads progress, so the card's upload note stays current
  window.txConnRefresh = function () { if (shown) fill(shownKind); };

  if (window.Shiny && Shiny.addCustomMessageHandler) register();
  else document.addEventListener('DOMContentLoaded', register);

  $(document).on('shiny:connected', function () {
    Shiny.setInputValue('tx_ua', navigator.userAgent);  // browser name for error reports
    var raw = null;
    try { raw = localStorage.getItem('tx_lost'); localStorage.removeItem('tx_lost'); } catch (e) {}
    if (!raw) return;
    try {
      var o = JSON.parse(raw);
      if (o && Date.now() - o.t < 24 * 3600 * 1000) Shiny.setInputValue('tx_lost_report', o, { priority: 'event' });
    } catch (e) {}
  });

  $(document).on('shiny:disconnected', function () {
    if (unloading) return;
    // Give a crash or idle message that is still on its way a moment to arrive
    setTimeout(function () {
      if (!crashId && !idleClosed) {
        try {
          localStorage.setItem('tx_lost', JSON.stringify({
            t: Date.now(), path: location.pathname, tab: activeTab(),
            sid: (window.Shiny && Shiny.shinyapp && Shiny.shinyapp.config) ? Shiny.shinyapp.config.sessionId : '',
            uploads: window.txUploadActive || 0
          }));
        } catch (e) {}
      }
      show(crashId ? 'crash' : (idleClosed ? 'idle' : 'lost'));
    }, 400);
  });

  window.addEventListener('beforeunload', function () { unloading = true; });
})();
