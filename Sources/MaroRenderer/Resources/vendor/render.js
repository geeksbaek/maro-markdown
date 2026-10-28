// Renders math and Mermaid diagrams in the Maro Markdown preview.
// Injected by the app as a WKUserScript; the page's own CSP blocks every script it references.
(function () {
  'use strict';

  var dark = window.matchMedia('(prefers-color-scheme: dark)');
  var diagramCount = 0;

  function renderMath(root) {
    if (!window.katex) return;
    root.querySelectorAll('.maro-math:not([data-rendered])').forEach(function (node) {
      var tex = node.textContent;
      node.setAttribute('data-source', tex);
      try {
        katex.render(tex, node, {
          displayMode: node.dataset.display === 'block',
          throwOnError: false,
          trust: false,
          strict: 'ignore'
        });
      } catch (error) {
        node.textContent = tex;
        node.classList.add('maro-error');
      }
      node.setAttribute('data-rendered', '');
    });
  }

  async function renderDiagrams(root) {
    if (!window.mermaid) return;
    var nodes = root.querySelectorAll('.maro-mermaid:not([data-rendered])');
    if (nodes.length === 0) return;
    mermaid.initialize({
      startOnLoad: false,
      securityLevel: 'strict',
      theme: dark.matches ? 'dark' : 'default'
    });
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      var source = node.textContent;
      node.setAttribute('data-source', source);
      node.setAttribute('data-rendered', '');
      try {
        var result = await mermaid.render('maro-mermaid-' + (++diagramCount), source);
        // securityLevel 'strict' sanitizes labels and drops click handlers, and the page
        // CSP (script-src 'none') keeps any script inside the SVG from running.
        node.innerHTML = result.svg;
      } catch (error) {
        var pre = document.createElement('pre');
        pre.className = 'maro-error';
        pre.textContent = source + '\n\n' + (error && error.message ? error.message : String(error));
        node.replaceChildren(pre);
      }
    }
  }

  window.maroRender = async function () {
    var root = document.getElementById('markdown') || document.body;
    renderMath(root);
    await renderDiagrams(root);
  };

  // Diagrams follow the system appearance; re-render them when it changes.
  dark.addEventListener('change', function () {
    document.querySelectorAll('.maro-mermaid[data-rendered]').forEach(function (node) {
      node.textContent = node.getAttribute('data-source') || '';
      node.removeAttribute('data-rendered');
    });
    window.maroRender();
  });

  // Hosts that need to know when the page is drawn (Quick Look) register this handler.
  window.maroRender().finally(function () {
    var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.maroRendered;
    if (handler) handler.postMessage(true);
  });
})();
