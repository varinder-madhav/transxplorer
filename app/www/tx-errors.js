/*
 * TransXplorer: explain a closed connection to the visitor.
 *
 * - The server sends "tx_crash" with a report ID when an error in the app's own code ends the
 *   session (the report is already saved and e-mailed); we show what happened and that ID.
 * - Any other lost connection (server restart, an app process stopped, network drop) shows a
 *   general message, and is remembered in localStorage so it can be reported to the server the next
 *   time the page connects.
 * Either way the visitor is asked to refresh, because a Shiny session cannot resume.
 */
(function () {
  var crashId = null, unloading = false, shown = false;

  function activeTab() {
    var a = document.querySelector('.navbar .nav > li.active > a, .navbar .nav-link.active');
    return a ? a.textContent.trim().slice(0, 60) : '';
  }

  function show(kind) {
    if (shown) { if (kind === 'crash') fill(kind); return; }
    shown = true;
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

  function fill(kind) {
    var w = document.getElementById('tx-conn-overlay');
    if (!w) return;
    w.className = 'tx-conn-' + kind;
    var t = w.querySelector('#tx-conn-title'), b = w.querySelector('.tx-conn-body');
    var reload = '<p>Please <strong>refresh the page</strong> to continue. Data you uploaded and results from ' +
      'this visit are not kept after a refresh, so you will need to load them again.</p>';
    if (kind === 'crash') {
      t.textContent = 'Something went wrong on our side';
      b.innerHTML =
        '<p>TransXplorer ran into an error in its own code. This was not caused by your data or settings.</p>' +
        '<p class="tx-conn-sent">An error report has been saved and sent to the TransXplorer team' +
        (crashId ? ' (report <code>' + crashId + '</code>)' : '') + '.</p>' + reload +
        '<p class="tx-conn-small">If the same step fails again, try other settings, or tell us what you were ' +
        'doing with <em>Send feedback</em> at the bottom of the page' +
        (crashId ? ' and mention the report number' : '') + '.</p>';
    } else {
      t.textContent = 'Connection to the server was lost';
      b.innerHTML =
        '<p>This can happen while the server restarts, when an analysis needs more memory than the server ' +
        'allows, or when your internet connection drops.</p>' + reload +
        '<p class="tx-conn-small">When you refresh, a short report of this disconnection is sent to the ' +
        'TransXplorer team automatically.</p>';
    }
  }

  function register() {
    Shiny.addCustomMessageHandler('tx_crash', function (m) { crashId = m && m.id; show('crash'); });
  }
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
    // Give a crash message that is still on its way a moment to arrive
    setTimeout(function () {
      if (!crashId) {
        try {
          localStorage.setItem('tx_lost', JSON.stringify({
            t: Date.now(), path: location.pathname, tab: activeTab(),
            sid: (window.Shiny && Shiny.shinyapp && Shiny.shinyapp.config) ? Shiny.shinyapp.config.sessionId : ''
          }));
        } catch (e) {}
      }
      show(crashId ? 'crash' : 'lost');
    }, 400);
  });

  window.addEventListener('beforeunload', function () { unloading = true; });
})();
