(function deepFindCaptchaSiteKeys(){
  // Deep sitekey finder - readable version
  // RETURNS: object { results: [...], log: [...] }
  // USAGE: paste whole function in Console and panggil; hasil akan tampil di modal dan dicopy otomatis.
  try {
    const log = [];
    const results = []; // { key, type, snippet, source }
    const seen = new Set();
    function add(key, type, snippet, source){
      if(!key && key !== 0) return;
      const k = String(key).trim();
      if(!k) return;
      const id = `${type}::${k}`;
      if(seen.has(id)) return;
      seen.add(id);
      results.push({ key: k, type, snippet: snippet ? String(snippet).slice(0,600) : '', source: source || document.location.href });
      log.push(`[ADD] ${type} -> ${k}`);
    }

    // Helper: try parse query params from a URL
    function extractFromUrl(url){
      if(!url) return [];
      try{
        const u = url.indexOf('://') === -1 ? ('http://'+url) : url;
        const parsed = new URL(u);
        const out = [];
        for(const [k,v] of parsed.searchParams.entries()){
          if(/^(k|sitekey|key|widget|data-sitekey)$/i.test(k) && v) out.push({key:v, part:`param:${k}`, url});
        }
        // also search raw path for k=VALUE patterns
        const m = url.match(/(?:\?|&|\/)(k|sitekey)=([A-Za-z0-9\-_]{6,})/i);
        if(m) out.push({key:m[2], part:'path-k', url});
        return out;
      }catch(e){
        // fallback: regex
        const rx = /(?:[?&\/](?:k|sitekey)=)([A-Za-z0-9\-_]{6,})/ig;
        const out = []; let mm;
        while((mm = rx.exec(url)) !== null){
          out.push({key:mm[1], part:'regex-url', url});
        }
        return out;
      }
    }

    // 1) Basic DOM attribute scans (most common)
    try {
      log.push('Scanning DOM attributes...');
      // any attr that looks like sitekey
      document.querySelectorAll('*').forEach(el=>{
        try{
          for(const attr of el.getAttributeNames ? el.getAttributeNames() : []){
            if(/sitekey|data-sitekey|data_key|data-k|captcha|recaptcha|turnstile|k\b/i.test(attr) || /g-recaptcha|turnstile|cf-turnstile/i.test(el.className||'')){
              const val = el.getAttribute(attr) || el.dataset && el.dataset.sitekey;
              if(val && /[A-Za-z0-9\-_]{6,}/.test(val)) add(val, `dom-attr:${attr}`, el.outerHTML.slice(0,400), window.location.href);
            }
          }
          // also check textContent for inline JSON configs
          const txt = (el.textContent||'').trim();
          if(txt.length < 4000 && /sitekey|data-sitekey|turnstile|grecaptcha|"k"\s*:/i.test(txt)){
            // run regex
            const rxes = [
              /data-sitekey\s*[:=]?\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig,
              /sitekey\s*[:=]\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig,
              /"k"\s*[:=]\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig,
              /"(?:k|sitekey)"\s*:\s*"([A-Za-z0-9\-_]{6,})"/ig
            ];
            for(const rx of rxes){
              let m; while((m = rx.exec(txt)) !== null){ add(m[1], 'inline-text', txt.slice(Math.max(0,m.index-120), m.index+120), 'element-text'); }
            }
          }
        }catch(e){}
      });
    } catch(e){ log.push('err dom scan:'+e); }

    // 2) Look for common widget containers
    try {
      log.push('Scanning common widget containers...');
      const selectors = ['.g-recaptcha','[data-sitekey]','.cf-turnstile','[class*="recaptcha"]','[class*="turnstile"]'];
      document.querySelectorAll(selectors.join(',')).forEach(el=>{
        const k = el.getAttribute('data-sitekey') || el.getAttribute('sitekey') || el.getAttribute('k') || (el.dataset && el.dataset.sitekey);
        if(k) add(k, 'widget-element', el.outerHTML.slice(0,400), 'dom');
      });
    } catch(e){}

    // 3) Iframes - scan src and attributes
    try {
      log.push('Scanning iframes...');
      document.querySelectorAll('iframe').forEach(iframe=>{
        try {
          const src = iframe.getAttribute('src') || '';
          if(src){
            extractFromUrl(src).forEach(o => add(o.key, 'iframe-src-param', src, src));
            // also look for encoded JSON or path tokens
            const m = src.match(/\/([A-Za-z0-9\-_]{20,})/);
            if(m) add(m[1], 'iframe-long-token', src, src);
          }
          // sometimes sitekey in title or name
          const name = iframe.getAttribute('name') || iframe.getAttribute('title');
          if(name && /[A-Za-z0-9\-_]{6,}/.test(name)) add(name.match(/[A-Za-z0-9\-_]{6,}/)[0], 'iframe-attr', name, src||document.location.href);
        }catch(e){}
      });
    } catch(e){}

    // 4) Inline and external script scan (inline text)
    try {
      log.push('Scanning inline scripts...');
      const scripts = Array.from(document.scripts || []);
      const sitekeyRegexes = [
        /data-sitekey\s*=\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig,
        /sitekey\s*[:=]\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig,
        /(?:k|sitekey)=([A-Za-z0-9\-_]{6,})/ig,
        /turnstile\.render\([^,]*,\s*\{[^}]*sitekey:\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig,
        /grecaptcha\.render\([^,]*,\s*\{[^}]*sitekey:\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig
      ];
      for(const s of scripts){
        try{
          const src = s.getAttribute('src');
          const txt = s.textContent || '';
          if(txt && txt.length>0){
            for(const rx of sitekeyRegexes){
              let m; while((m = rx.exec(txt)) !== null){ add(m[1], 'inline-script', txt.slice(Math.max(0,m.index-120), m.index+120), src || 'inline'); }
            }
          }
        }catch(e){}
      }
    } catch(e){ log.push('err script inline:'+e); }

    // 5) Try fetching same-origin external scripts (best-effort)
    try {
      log.push('Attempt fetch same-origin external scripts (best-effort)...');
      const scripts = Array.from(document.scripts || []).map(s => s.getAttribute('src')).filter(Boolean);
      const sameOrigin = scripts.filter(u=>{
        try{
          const url = new URL(u, location.href);
          return url.origin === location.origin;
        }catch(e){ return false; }
      });
      for(const u of sameOrigin){
        try{
          const res = await fetch(u, {cache: 'no-cache'}); // note: in bookmarklet context, awaiting is allowed inside async IIFE; here we are inside sync — to keep safe, use then()
        }catch(e){}
      }
    } catch(e){ /* ignore - we'll implement non-await fallback below */ }

    // Because direct await/async inside IIFE might be awkward for bookmarklet, we implement a fetch chain for same-origin scripts:
    (function fetchSameOriginScriptsChain(){
      try{
        const scriptSrcs = Array.from(document.scripts || []).map(s=>s.getAttribute('src')).filter(Boolean);
        const same = scriptSrcs.filter(u=>{ try{ return new URL(u,location.href).origin === location.origin;}catch(e){return false;} });
        if(same.length===0) { log.push('No same-origin external scripts found.'); return; }
        let p = Promise.resolve();
        same.forEach(src=>{
          p = p.then(()=>fetch(src, {cache:'no-cache'}).then(r=>r.text()).then(text=>{
            try{
              // scan text
              const rx = /(data-sitekey|sitekey|k)[^A-Za-z0-9\-_]{0,5}[:=]?\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig;
              let m; while((m = rx.exec(text)) !== null){ add(m[2], 'fetched-script', text.slice(Math.max(0,m.index-120), m.index+120), src); }
            }catch(e){}
          }).catch(e=>{ log.push('fetch fail:'+src+ ' -> '+ e); }));
        });
        p.catch(()=>{});
      }catch(e){}
    })();

    // 6) Resource timing scan (resources that loaded may have sitekey in query)
    try {
      log.push('Scanning performance resources...');
      if(window.performance && performance.getEntries){
        const entries = performance.getEntries().filter(e=>e.name && /k=|sitekey=|recaptcha/i.test(e.name));
        entries.forEach(en=>{
          extractFromUrl(en.name).forEach(o => add(o.key, 'perf-resource', en.name, en.name));
        });
      }
    } catch(e){}

    // 7) Monkey-patch fetch / XHR to capture future dynamic loads (best-effort)
    try {
      log.push('Monkey patch fetch & XHR to capture future requests (will auto-log new matches)...');
      if(!window.__deepCaptchaPatched){
        window.__deepCaptchaPatched = true;
        const origFetch = window.fetch;
        window.fetch = function(...args){
          try{
            const url = String(args[0] || '');
            extractFromUrl(url).forEach(o=>add(o.key,'fetch-call', url, document.location.href));
          }catch(e){}
          return origFetch.apply(this, args).then(res=>{
            // try clone & text scan (best-effort, may be blocked by CORS)
            try{
              const clone = res.clone();
              clone.text().then(txt=>{
                try{
                  const rx = /(data-sitekey|sitekey|k)[^A-Za-z0-9\-_]{0,5}[:=]?\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig;
                  let m; while((m=rx.exec(txt))!==null) add(m[2],'fetch-response',txt.slice(Math.max(0,m.index-120), m.index+120), args[0]);
                }catch(e){}
              }).catch(()=>{});
            }catch(e){}
            return res;
          });
        };
        // XHR
        const origOpen = XMLHttpRequest.prototype.open;
        const origSend = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function(method, url){
          try{ extractFromUrl(url).forEach(o=>add(o.key,'xhr-open',url,document.location.href)); }catch(e){}
          this.__deep_xhr_url = url;
          return origOpen.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function(body){
          this.addEventListener && this.addEventListener('load', function(){
            try{
              const ct = this.getResponseHeader && this.getResponseHeader('content-type') || '';
              if(typeof this.response === 'string' || ct.includes('application/json') || ct.includes('text')){
                const txt = typeof this.response === 'string' ? this.response : (this.responseText || '');
                const rx = /(data-sitekey|sitekey|k)[^A-Za-z0-9\-_]{0,5}[:=]?\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig;
                let m; while((m = rx.exec(txt)) !== null) add(m[2],'xhr-response', txt.slice(Math.max(0,m.index-120), m.index+120), this.__deep_xhr_url || document.location.href);
              }
            }catch(e){}
          });
          return origSend.apply(this, arguments);
        };
      } else {
        log.push('Already patched fetch/XHR earlier.');
      }
    } catch(e){ log.push('patch err:'+e); }

    // 8) MutationObserver to catch dynamic injections (e.g. widget loaded later)
    try {
      log.push('Attaching MutationObserver for dynamic elements (will watch for 10s)...');
      const mo = new MutationObserver((mutations)=>{
        try{
          mutations.forEach(m=>{
            m.addedNodes && m.addedNodes.forEach(node=>{
              try{
                if(node.nodeType !== 1) return;
                const el = node;
                // quick scan attributes & innerText
                for(const attr of el.getAttributeNames ? el.getAttributeNames() : []){
                  if(/sitekey|data-sitekey|k/i.test(attr)){
                    const v = el.getAttribute(attr);
                    if(v) add(v, 'mutation-attr:'+attr, el.outerHTML.slice(0,400), 'mutation');
                  }
                }
                const txt = (el.textContent||'');
                if(/sitekey|data-sitekey|k=|turnstile|grecaptcha/i.test(txt)){
                  const rx = /(data-sitekey|sitekey|k)[^A-Za-z0-9\-_]{0,5}[:=]?\s*["'`]([A-Za-z0-9\-_]{6,})["'`]/ig;
                  let m; while((m = rx.exec(txt)) !== null){ add(m[2],'mutation-text', txt.slice(Math.max(0,m.index-120), m.index+120), 'mutation'); }
                }
              }catch(e){}
            });
          });
        }catch(e){}
      });
      mo.observe(document.documentElement || document.body, { childList:true, subtree:true, attributes:true, characterData:true });
      // stop observing after 10s
      setTimeout(()=>{ mo.disconnect(); log.push('Mutation observer stopped (10s elapsed)'); finalize(); }, 10000);
    } catch(e){ log.push('mut obs err:'+e); finalize(); return; }

    // 9) Deep scan of HTML (last resort) - may be heavy on large pages
    try {
      log.push('Deep-scanning full HTML (this may be slow)...');
      try{
        const html = document.documentElement.innerHTML;
        const fullRegex = /(data-sitekey|sitekey|k)[^A-Za-z0-9\-_]{0,6}["'=:\s]*["']?([A-Za-z0-9\-_]{6,})["']?/gi;
        let m;
        while((m = fullRegex.exec(html)) !== null){
          add(m[2], 'html-scan', html.slice(Math.max(0,m.index-120), m.index+120), document.location.href);
        }
      }catch(e){}
    } catch(e){}

    // FINALIZE: show UI, copy to clipboard
    function finalize(){
      try{
        // prepare text
        const lines = results.map(r => `${r.type}: ${r.key}  —  ${r.snippet ? r.snippet.replace(/\n/g,' ').slice(0,120) : ''}`);
        const text = lines.length ? ('Found keys:\n\n' + lines.join('\n')) : 'No sitekey/k found on this page (yet).';
        // copy to clipboard
        (function copyStr(s){
          if(navigator.clipboard && navigator.clipboard.writeText){
            navigator.clipboard.writeText(s).catch(()=>fallbackCopy(s));
          } else fallbackCopy(s);
          function fallbackCopy(str){
            try{
              const ta = document.createElement('textarea'); ta.value = str;
              ta.style.position='fixed'; ta.style.left='0'; ta.style.top='0'; ta.style.opacity='0';
              document.body.appendChild(ta); ta.focus(); ta.select();
              document.execCommand('copy'); document.body.removeChild(ta);
            }catch(e){ console.warn('copy failed', e); }
          }
        })(text);

        // small modal UI
        try{
          const existing = document.getElementById('__deepCaptchaFinder_modal');
          if(existing) existing.remove();
          const modal = document.createElement('div');
          modal.id = '__deepCaptchaFinder_modal';
          modal.style.position = 'fixed';
          modal.style.right = '12px';
          modal.style.top = '12px';
          modal.style.zIndex = 2147483647;
          modal.style.maxWidth = '520px';
          modal.style.maxHeight = '60vh';
          modal.style.overflow = 'auto';
          modal.style.background = 'rgba(20,20,20,0.96)';
          modal.style.color = '#fff';
          modal.style.fontSize = '13px';
          modal.style.borderRadius = '8px';
          modal.style.boxShadow = '0 6px 24px rgba(0,0,0,0.6)';
          modal.style.padding = '12px';
          modal.style.fontFamily = 'system-ui,Segoe UI, Roboto, Helvetica, Arial';
          // header
          const h = document.createElement('div');
          h.style.display='flex'; h.style.gap='8px'; h.style.alignItems='center'; h.style.marginBottom='8px';
          h.innerHTML = '<strong style="font-size:14px">Deep Captcha SiteKey Finder</strong><span style="opacity:0.7;font-size:12px"> (copied to clipboard)</span>';
          const btnClose = document.createElement('button'); btnClose.textContent='×'; btnClose.title='Close'; btnClose.style.marginLeft='auto';
          btnClose.onclick = ()=>{ modal.remove(); };
          btnClose.style.background='transparent'; btnClose.style.border='none'; btnClose.style.color='#fff'; btnClose.style.fontSize='18px'; btnClose.style.cursor='pointer';
          h.appendChild(btnClose);
          modal.appendChild(h);
          // list
          const list = document.createElement('div');
          if(results.length===0){
            const p = document.createElement('div'); p.textContent = 'No sitekey/k found on page (so far). Try interact with the page or reload and run again.'; p.style.opacity='0.9';
            list.appendChild(p);
          } else {
            results.forEach((r, i) => {
              const row = document.createElement('div'); row.style.display='flex'; row.style.gap='8px'; row.style.alignItems='center';
              row.style.marginBottom='6px';
              const info = document.createElement('div'); info.style.flex='1';
              const t = document.createElement('div'); t.textContent = `${r.type}: ${r.key}`; t.style.fontWeight='600';
              const s = document.createElement('div'); s.textContent = (r.snippet||'').replace(/\s+/g,' ').slice(0,220); s.style.opacity='0.8'; s.style.fontSize='12px';
              info.appendChild(t); info.appendChild(s);
              const copyBtn = document.createElement('button'); copyBtn.textContent='Copy'; copyBtn.style.cursor='pointer';
              copyBtn.onclick = ()=>{ navigator.clipboard && navigator.clipboard.writeText(r.key).then(()=>{ copyBtn.textContent='Copied'; setTimeout(()=>copyBtn.textContent='Copy',900); }).catch(()=>{ /* fallback */ const ta=document.createElement('textarea'); ta.value=r.key; document.body.appendChild(ta); ta.select(); document.execCommand('copy'); document.body.removeChild(ta); copyBtn.textContent='Copied'; setTimeout(()=>copyBtn.textContent='Copy',900); }); };
              row.appendChild(info); row.appendChild(copyBtn);
              list.appendChild(row);
            });
            // copy all button
            const copyAll = document.createElement('button'); copyAll.textContent='Copy all keys'; copyAll.style.marginTop='8px'; copyAll.style.cursor='pointer';
            copyAll.onclick = ()=>{ const all = results.map(r=>r.key).join('\\n'); if(navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(all); else { const ta=document.createElement('textarea'); ta.value=all; document.body.appendChild(ta); ta.select(); document.execCommand('copy'); document.body.removeChild(ta);} copyAll.textContent='Copied'; setTimeout(()=>copyAll.textContent='Copy all keys',1000); };
            modal.appendChild(list); modal.appendChild(copyAll);
          }
          // add log toggle
          const logToggle = document.createElement('details'); logToggle.style.marginTop='8px'; logToggle.innerHTML = '<summary style="cursor:pointer">Debug log</summary>';
          const pre = document.createElement('pre'); pre.style.whiteSpace='pre-wrap'; pre.style.maxHeight='200px'; pre.style.overflow='auto'; pre.style.fontSize='12px'; pre.style.opacity='0.9';
          pre.textContent = log.concat(['-- results --']).concat(results.map(r=>`${r.type}: ${r.key}`)).join('\\n');
          logToggle.appendChild(pre); modal.appendChild(logToggle);
          document.body.appendChild(modal);
        }catch(e){ console.warn('ui failed', e); }
        // final console
        console.log('DeepCaptchaFinder results:', results);
      }catch(e){ console.warn('finalize err', e); }
    }

    // If MutationObserver will stop after 10s, finalize will be called then. But in case no MO set (edge), call finalize after 2s
    setTimeout(()=>{ try{ finalize(); }catch(e){} }, 2500);

    // NOTE: We already set a timeout to stop MO after 10s, so results may appear as dynamically loaded items are observed.
    return { results, log };
  } catch(err){
    console.error('deepFindCaptchaSiteKeys error', err);
    alert('Error running Deep Captcha Finder: '+err);
    return { results:[], log:['error:'+String(err)] };
  }
})();
