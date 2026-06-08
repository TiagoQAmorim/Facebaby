(function () {
  var SECTION_RE = /^\d+\.\s+\S/;
  var DEFINITION_LABEL_RE = /^[A-Za-z0-9"«][^:\n]{0,36}:\s*\S/;
  var META_RE = /(Última atualização|Last Updated|Última actualización|Ultimo aggiornamento|Dernière mise à jour|Letzte Aktualisierung|EN-US|PT-BR)/i;
  var SUBSECTION_TITLE_RE = /^(Plano Gratuito|Plano Premium Mensal|Plano Premium Anual|Free Plan|Monthly Premium Plan|Annual Premium Plan|Plan Gratuit|Plan Premium Mensuel|Plan Premium Annuel|Kostenloser Plan|Monatliches Premium-Abo|Jährliches Premium-Abo|Piano Gratuito|Piano Premium Mensile|Piano Premium Annuale|Account Data|Baby Data|Technical Data|Dados da Conta|Dados do Bebê|Fotografias e Conteúdo|Dados Técnicos|Dados de Assinatura|Photographs and Submitted Content|Subscription Data)$/i;

  function isDefinitionLine(line) {
    if (!DEFINITION_LABEL_RE.test(line)) return false;
    var label = line.split(':', 1)[0].trim();
    if (label.split(/\s+/).length > 3) return false;
    var lower = label.toLowerCase();
    var markers = ['include', 'incluir', 'podem', 'may', 'poder', 'agree', 'reconhece', 'substitu', 'replace', 'proibido', 'armazen', 'store', 'contra', 'against', 'responsible for', 'disposi'];
    return !markers.some(function (m) { return lower.indexOf(m) >= 0; });
  }

  function isSubsectionTitle(line, lines, index) {
    var t = line.trim();
    if (!t || t.length > 72 || t.endsWith(':') || t.endsWith('.') || t.endsWith(';')) return false;
    if (SECTION_RE.test(t) || /^[a-z]/.test(t)) return false;
    for (var i = index + 1; i < lines.length; i++) {
      var next = lines[i].trim();
      if (!next) continue;
      return next.startsWith('• ') || next.startsWith('- ');
    }
    return false;
  }

  function preprocess(raw) {
    var t = raw.replace(/\r\n/g, '\n').trim();
    t = t.replace(/\.(\d+\.\s+)/g, '.\n\n$1');
    t = t.replace(/(?<=\S)\n(\d+\.\s+)/g, '\n\n$1');
    t = t.replace(/^(\d+\.\s+[^\n]+)\n(?=\S)/gm, '$1\n\n');
    return t.replace(/\n{3,}/g, '\n\n');
  }

  function renderLegal(rawText, container) {
    var lines = preprocess(rawText).split('\n');
    var frag = document.createDocumentFragment();
    var titleDone = false;
    var metaDone = false;
    var sectionCount = 0;

    function append(el) { frag.appendChild(el); }

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (!line) continue;

      if (!titleDone) {
        var h = document.createElement('h1');
        h.className = 'legal-doc__title';
        h.textContent = line;
        append(h);
        titleDone = true;
        continue;
      }

      if (!metaDone && META_RE.test(line) && !SECTION_RE.test(line)) {
        var meta = document.createElement('p');
        meta.className = 'legal-doc__meta';
        meta.textContent = line;
        append(meta);
        metaDone = true;
        continue;
      }

      if (SECTION_RE.test(line)) {
        if (sectionCount > 0) append(document.createElement('br'));
        sectionCount++;
        var section = document.createElement('h2');
        section.className = 'legal-doc__section';
        section.textContent = line;
        append(section);
        continue;
      }

      if (line.startsWith('• ') || line.startsWith('- ')) {
        var ul = document.createElement('ul');
        while (i < lines.length) {
          var bullet = lines[i].trim();
          if (!bullet) { i++; continue; }
          if (!(bullet.startsWith('• ') || bullet.startsWith('- '))) break;
          var li = document.createElement('li');
          li.textContent = bullet.replace(/^[-•·]\s*/, '');
          ul.appendChild(li);
          i++;
        }
        i--;
        append(ul);
        continue;
      }

      if (isSubsectionTitle(line, lines, i) || SUBSECTION_TITLE_RE.test(line)) {
        var sub = document.createElement('h3');
        sub.className = 'legal-doc__subsection';
        sub.textContent = line;
        append(sub);
        continue;
      }

      if (isDefinitionLine(line)) {
        var def = document.createElement('p');
        def.innerHTML = '<strong>' + line.split(':')[0] + ':</strong>' + line.slice(line.indexOf(':') + 1);
        append(def);
        continue;
      }

      var para = document.createElement('p');
      var text = line;
      while (i + 1 < lines.length) {
        var next = lines[i + 1].trim();
        if (!next || SECTION_RE.test(next)) break;
        if (next.startsWith('• ') || next.startsWith('- ')) break;
        if (isSubsectionTitle(next, lines, i + 1) || SUBSECTION_TITLE_RE.test(next)) break;
        if (isDefinitionLine(next)) break;
        i++;
        text += ' ' + lines[i].trim();
      }
      para.textContent = text;
      append(para);
    }

    container.innerHTML = '';
    container.appendChild(frag);
  }

  window.FaceBabyLegal = {
    render: function (url, containerId) {
      var container = document.getElementById(containerId);
      if (!container) return;
      fetch(url)
        .then(function (r) {
          if (!r.ok) throw new Error('load failed');
          return r.text();
        })
        .then(function (text) { renderLegal(text, container); })
        .catch(function () {
          container.innerHTML = '<p>Unable to load this document. Please email <a href="mailto:support@thefacebaby.com">support@thefacebaby.com</a>.</p>';
        });
    }
  };
})();
