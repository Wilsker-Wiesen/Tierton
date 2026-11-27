/* Tierton web – the browser version of the iOS app (same content, same modes). */
"use strict";

const $app = document.getElementById("app");
const $card = document.getElementById("card");
let DATA = { categories: [], animals: [] };
let CAT = {};
const EMOJI = { arktis: "❄️", wald: "🌲", bauernhof: "🏡", haustiere: "🐾", stadt: "🏙️", wasser: "🌊", savanne: "☀️", dschungel: "🌿", australien: "🦘", antarktis: "🧊" };

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const shuffle = (a) => { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; };
const pick = (a) => a[Math.floor(Math.random() * a.length)];
const store = {
  get(k, d) { try { const v = localStorage.getItem("tierton." + k); return v == null ? d : JSON.parse(v); } catch { return d; } },
  set(k, v) { try { localStorage.setItem("tierton." + k, JSON.stringify(v)); } catch {} },
};

/* ---------- sound ---------- */
const audio = new Audio();
audio.preload = "auto";
let playingId = null;
const onPlayChange = new Set();
function setPlaying(id) { playingId = id; onPlayChange.forEach(f => f()); }
function play(a) {
  audio.pause();
  audio.src = `media/${a.id}.m4a`;
  audio.currentTime = 0;
  audio.play().then(() => setPlaying(a.id)).catch(() => setPlaying(null));
}
function stop() { audio.pause(); setPlaying(null); }
function toggle(a) { if (playingId === a.id && !audio.paused) stop(); else play(a); }
audio.addEventListener("ended", () => setPlaying(null));

/* ---------- the shared look: animal peeking out of a circle in its habitat colour ---------- */
function popOut(a, opacity = 0.28) {
  const c = CAT[a.category]?.color || "#888";
  const W = 100, H = 100, d = 84, cy = H * 0.97 - d, mid = cy + d / 2;
  const aspect = a.w / Math.max(a.h, 1);
  let x, y, w, h;
  if (aspect > 1.25) {
    h = Math.min(W / aspect, H * 0.9); w = h * aspect;
    const bottom = Math.min(cy + d - d * 0.05, mid - d * 0.06 + h / 2);
    x = (W - w) / 2; y = bottom - h;
  } else {
    const s = Math.min(W * 0.92 / a.w, H * 0.95 / a.h);
    w = a.w * s; h = a.h * s; x = (W - w) / 2; y = cy + d - d * 0.05 - h;
  }
  const id = "c" + Math.random().toString(36).slice(2, 8);
  return `<div class="pop"><svg viewBox="0 0 100 100" aria-hidden="true">
    <defs><clipPath id="${id}"><circle cx="50" cy="${mid}" r="${d / 2}"/><rect x="0" y="0" width="100" height="${mid}"/></clipPath></defs>
    <circle cx="50" cy="${mid}" r="${d / 2}" fill="${c}" fill-opacity="${opacity}"/>
    <image href="media/${a.id}.webp" x="${x}" y="${y}" width="${w}" height="${h}" clip-path="url(#${id})"/>
  </svg></div>`;
}

/* ---------- navigation ---------- */
const MODES = {
  entdecken: { title: "Entdecken", render: explore },
  raetsel: { title: "Rätsel zu zweit", render: together },
  quiz: { title: "Quiz", render: quiz },
  sagslaut: { title: "Sag's laut!", render: voice },
  nachweise: { title: "Nachweise", render: credits },
};
let cleanup = () => {};
function route() {
  cleanup(); cleanup = () => {};
  stop(); onPlayChange.clear();
  const m = MODES[location.hash.slice(1)];
  window.scrollTo(0, 0);
  if (!m) return home();
  m.render();
}
window.addEventListener("hashchange", route);
const bar = (title, extra = "") => `<div class="bar"><button class="round-btn" onclick="location.hash=''" aria-label="Zurück">‹</button><h1>${title}</h1>${extra || '<span class="spacer"></span>'}</div>`;

/* ---------- home ---------- */
function home() {
  const pics = ["loewe", "eisbaer", "kaiserpinguin", "elefant", "amsel", "tukan", "koala"].map(id => DATA.animals.find(a => a.id === id)).filter(Boolean).slice(0, 5);
  const voiceOk = !!(window.SpeechRecognition || window.webkitSpeechRecognition);
  const modes = [
    ["entdecken", "🔭", "#2E8B57", "Entdecken", "Scroll von der Arktis bis zum Südpol. Tippe ein Tier an und hör, wie es klingt."],
    ["raetsel", "👥", "#C0603A", "Rätsel zu zweit", "Einer spielt ein Geräusch ab, der andere rät, welches Tier das war."],
    ["quiz", "⚡", "#2F78A8", "Quiz", "Du hörst ein Geräusch – finde so schnell wie möglich das richtige Tier."],
    ...(voiceOk ? [["sagslaut", "🎤", "#8E5BB5", "Sag's laut!", "Ein Tier ist zu hören, aber nicht zu sehen. Sag einfach laut, welches Tier es ist."]] : []),
  ];
  $app.innerHTML = `<div class="wrap">
    <div class="hero"><h1>Tierton</h1><p>${DATA.animals.length} Tiere und ihre Stimmen</p>
      <div class="mosaic">${pics.map(a => popOut(a)).join("")}</div></div>
    <div class="modes">${modes.map(([k, ic, c, t, s]) => `<button class="mode" onclick="location.hash='${k}'"><span class="ic" style="background:${c}">${ic}</span><span><b>${t}</b><span>${s}</span></span></button>`).join("")}</div>
    <button class="link" onclick="location.hash='nachweise'">ⓘ Bild- und Tonnachweise</button>
  </div>`;
}

/* ---------- tiles ---------- */
function tile(a, { info = false, name = true, live = true } = {}) {
  const c = CAT[a.category]?.color || "#888";
  return `<button class="tile" data-id="${a.id}" style="--c:${c}" aria-label="${esc(a.name)}">
    ${popOut(a)}
    ${name || info ? `<span class="name">${name ? `<b>${esc(a.name)}</b>` : "<b></b>"}${info ? `<span class="info" role="button" data-info="${a.id}" aria-label="Infos zu ${esc(a.name)}">i</span>` : ""}</span>` : ""}
    ${live ? `<span class="badge" hidden>🔊</span>` : ""}
  </button>`;
}
function bindLive(root) {
  const upd = () => root.querySelectorAll(".tile").forEach(t => {
    const on = t.dataset.id === playingId;
    t.classList.toggle("playing", on);
    const b = t.querySelector(".badge"); if (b) b.hidden = !on;
  });
  onPlayChange.add(upd);
}
const byId = (id) => DATA.animals.find(a => a.id === id);

/* ---------- Entdecken ---------- */
function explore() {
  let birdsOnly = false;
  const draw = () => {
    const cats = DATA.categories.filter(c => DATA.animals.some(a => a.category === c.id && (!birdsOnly || a.bird)));
    $app.innerHTML = `<div class="wrap">${bar("Entdecken", `<button class="round-btn" id="birds" aria-pressed="${birdsOnly}" aria-label="Nur Vögel">🐦</button>`)}
      <div class="chips">${cats.map(c => `<button class="chip" style="--c:${c.color}" data-jump="${c.id}">${esc(c.name)}</button>`).join("")}</div>
      ${cats.map(c => `<div class="sec" id="s-${c.id}" style="--c:${c.color}"><span class="ic">${EMOJI[c.id] || ""}</span><div><b>${esc(c.name)}</b><span>${esc(c.subtitle)}</span></div></div>
        <div class="grid">${DATA.animals.filter(a => a.category === c.id && (!birdsOnly || a.bird)).map(a => tile(a, { info: true })).join("")}</div>`).join("")}
    </div>`;
    $app.querySelector("#birds").onclick = () => { birdsOnly = !birdsOnly; draw(); };
    $app.querySelectorAll("[data-jump]").forEach(b => b.onclick = () => document.getElementById("s-" + b.dataset.jump).scrollIntoView({ behavior: "smooth" }));
    $app.querySelectorAll(".tile").forEach(t => t.onclick = (e) => {
      const a = byId(t.dataset.id);
      if (e.target.closest("[data-info]")) { showCard(a); return; }
      toggle(a);
    });
    onPlayChange.clear(); bindLive($app);
  };
  draw();
}

/* ---------- info card (quartet) ---------- */
const IUCN = { LC: ["Nicht gefährdet", "#3E9B4F", 0], NT: ["Potenziell gefährdet", "#8DB43B", 1], VU: ["Gefährdet", "#E2B12C", 2], EN: ["Stark gefährdet", "#E07A27", 3], CR: ["Vom Aussterben bedroht", "#D23B32", 4], DD: ["Unzureichende Datenlage", "#888", -1] };
function showCard(a) {
  const c = CAT[a.category]; const f = a.facts || {};
  const rows = [["Größe", f.laenge], ["Gewicht", f.gewicht], ["Alter", f.alter], ["Tempo", f.tempo], ["Nachwuchs", f.nachwuchs], ["Wie oft", f.wieOft], ["Tragzeit / Brut", f.tragzeit], ["Nahrung", f.nahrung], ["Lebensraum", f.lebensraum]].filter(r => r[1]);
  const st = IUCN[a.iucn];
  const cr = (kind, m) => m ? `<div>${kind}${m.edited ? ` (${esc(m.edited)})` : ""}: ${esc(m.artist || "unbekannt")}, ${esc(m.license || "")}, <a href="${esc(m.page)}" target="_blank" rel="noopener">Wikimedia Commons</a></div>` : "";
  $card.innerHTML = `<div class="card" style="--c:${c.color}">
    <button class="close" id="cclose">Fertig</button>
    <div class="hero-pop">${popOut(a, .32)}<button class="play" id="cplay" aria-label="Geräusch abspielen">▶</button></div>
    <div><h2>${esc(a.name)}</h2><div class="sci">${esc(a.sci)}</div><div style="color:${c.color};font-weight:800">${esc(c.name)}</div></div>
    ${f.geraeusch ? `<div><b>〰 ${esc(f.geraeusch)}</b></div>` : ""}
    <div class="facts">${rows.map(([k, v]) => `<div class="fact"><small>${k}</small><b>${esc(v)}</b></div>`).join("")}</div>
    ${st ? `<div class="panel"><p class="label">Rote Liste (IUCN)</p>${st[2] >= 0 ? `<div class="iucn">${["LC", "NT", "VU", "EN", "CR"].map(k => `<span style="--k:${IUCN[k][1]}" class="${k === a.iucn ? "on" : ""}">${k}</span>`).join("")}</div>` : ""}<p style="color:${st[1]};font-weight:800;margin:8px 0 0">${st[0]}</p></div>` : ""}
    ${f.fakt ? `<div class="panel"><p class="label">💡 Schon gewusst?</p>${esc(f.fakt)}</div>` : ""}
    <div class="credit">${cr("Foto", a.credits.image)}${cr("Ton", a.credits.sound)}<div>Werte sind typische Angaben für erwachsene Tiere.</div></div>
  </div>`;
  const btn = $card.querySelector("#cplay");
  const upd = () => { btn.textContent = playingId === a.id ? "■" : "▶"; };
  btn.onclick = () => toggle(a);
  onPlayChange.add(upd);
  $card.querySelector("#cclose").onclick = () => $card.close();
  $card.onclose = () => { onPlayChange.delete(upd); stop(); };
  $card.showModal();
  play(a);
}
$card.addEventListener("click", (e) => { if (e.target === $card) $card.close(); });

/* ---------- category filter (shared by games) ---------- */
function filterChips(state, onChange) {
  const el = document.createElement("div");
  el.className = "chips";
  const draw = () => {
    el.innerHTML = `<button class="chip" style="--c:#2E8B57" data-k="all" aria-pressed="${state.cats.size === 0}">Alle</button>
      <button class="chip" style="--c:#8E5BB5" data-k="birds" aria-pressed="${state.birds}">🐦 Nur Vögel</button>
      ${DATA.categories.map(c => `<button class="chip" style="--c:${c.color}" data-k="${c.id}" aria-pressed="${state.cats.has(c.id)}">${esc(c.name)}</button>`).join("")}`;
    el.querySelectorAll(".chip").forEach(b => b.onclick = () => {
      const k = b.dataset.k;
      if (k === "all") state.cats.clear(); else if (k === "birds") state.birds = !state.birds;
      else state.cats.has(k) ? state.cats.delete(k) : state.cats.add(k);
      draw(); onChange();
    });
  };
  draw();
  return el;
}
const poolOf = (st) => DATA.animals.filter(a => (st.cats.size === 0 || st.cats.has(a.category)) && (!st.birds || a.bird));

/* ---------- Rätsel zu zweit ---------- */
function together() {
  const st = { cats: new Set(), birds: false, mode: "random", recent: [] };
  const C = "#C0603A";
  const setup = () => {
    $app.innerHTML = `<div class="wrap">${bar("Rätsel zu zweit")}<div class="stack">
      <div class="seg"><button data-m="random" aria-pressed="${st.mode === "random"}">Zufall</button><button data-m="pick" aria-pressed="${st.mode === "pick"}">Ich suche aus</button></div>
      <div id="flt"></div><div id="body"></div></div></div>`;
    $app.querySelectorAll(".seg button").forEach(b => b.onclick = () => { st.mode = b.dataset.m; setup(); });
    $app.querySelector("#flt").append(filterChips(st, body));
    body();
  };
  const body = () => {
    const pool = poolOf(st), el = $app.querySelector("#body");
    if (st.mode === "random") {
      el.innerHTML = `<div class="center stack"><p style="font-size:1.2rem">Drück den Knopf, ein zufälliges Tier ist zu hören. Die anderen raten!</p>
        <p class="muted">${pool.length} Tiere in der Auswahl</p><button class="big" style="--c:${C}" id="go" ${pool.length ? "" : "disabled"}>▶ Geräusch abspielen</button></div>`;
      el.querySelector("#go").onclick = () => {
        const fresh = pool.filter(a => !st.recent.includes(a.id));
        const a = pick(fresh.length ? fresh : pool);
        st.recent.push(a.id); if (st.recent.length > Math.min(15, Math.max(1, pool.length >> 1))) st.recent.shift();
        hidden(a);
      };
    } else {
      el.innerHTML = `<p class="muted">🙈 Such dir heimlich ein Tier aus. Die anderen dürfen nicht hinsehen!</p><div class="grid">${pool.map(a => tile(a, { live: false })).join("")}</div>`;
      el.querySelectorAll(".tile").forEach(t => t.onclick = () => hidden(byId(t.dataset.id)));
    }
  };
  const hidden = (a) => {
    $app.innerHTML = `<div class="wrap">${bar("Rätsel zu zweit")}<div class="stack center" style="--c:${C}">
      <button class="mystery" id="mys">?</button><h2 style="font-size:2rem;margin:0">Welches Tier ist das?</h2>
      <div class="row"><button class="big gray" id="again">↻ Nochmal</button><button class="big" style="--c:${C}" id="reveal">👁 Auflösen</button></div></div></div>`;
    const mys = $app.querySelector("#mys");
    const upd = () => { mys.textContent = playingId === a.id ? "🔊" : "?"; };
    onPlayChange.add(upd);
    mys.onclick = $app.querySelector("#again").onclick = () => play(a);
    $app.querySelector("#reveal").onclick = () => revealed(a);
    play(a);
  };
  const revealed = (a) => {
    onPlayChange.clear();
    const c = CAT[a.category];
    $app.innerHTML = `<div class="wrap">${bar("Rätsel zu zweit")}<div class="stack center">
      <div style="max-width:380px;margin:0 auto;width:100%" id="pic">${popOut(a, .32)}</div>
      <h2 style="font-size:2.2rem;margin:0">${esc(a.name)}</h2><div style="color:${c.color};font-weight:800">${esc(c.name)}</div>
      <button class="txtlink" id="more">ⓘ Mehr über das Tier</button>
      <div class="row"><button class="big gray" id="set">Einstellungen</button><button class="big" style="--c:${C}" id="next">⏭ Nächstes Tier</button></div></div></div>`;
    $app.querySelector("#pic").onclick = () => toggle(a);
    $app.querySelector("#more").onclick = () => showCard(a);
    $app.querySelector("#set").onclick = () => { stop(); setup(); };
    $app.querySelector("#next").onclick = () => { if (st.mode === "random") { setup(); $app.querySelector("#go")?.click(); } else { stop(); setup(); } };
    play(a);
  };
  setup();
}

/* ---------- Quiz: all animals, or the 10/20 that sound most alike ---------- */
const NEIGH = { zwitschern: ["kreischen", "rufen", "zirpen"], kreischen: ["zwitschern", "rufen", "wasservogel"], rufen: ["kreischen", "wasservogel", "zwitschern"], wasservogel: ["rufen", "kreischen", "meer"], bruellen: ["heulen", "grunzen", "affen"], heulen: ["bruellen", "affen", "blöken"], "blöken": ["grunzen", "heulen", "bruellen"], grunzen: ["blöken", "bruellen", "meer"], affen: ["bruellen", "heulen", "kreischen"], meer: ["wasservogel", "grunzen", "bruellen"], zirpen: ["zwitschern", "rufen", "grunzen"] };
function similar(ans, pool, n) {
  const others = pool.filter(a => a.id !== ans.id);
  let order = shuffle(others.filter(a => a.klang === ans.klang));
  for (const g of NEIGH[ans.klang] || []) order = order.concat(shuffle(others.filter(a => a.klang === g)));
  order = order.concat(shuffle(others.filter(a => !order.includes(a))));
  return shuffle(order.slice(0, n - 1).concat([ans]));
}
function quiz() {
  const ROUNDS = 10, Q = "#2F78A8";
  const st = { cats: new Set(), birds: false, choices: store.get("quizChoices", 20), names: true };
  let rounds = [], score = 0, streak = 0, last = 0;
  const setup = () => {
    const best = store.get("quizBest", 0);
    $app.innerHTML = `<div class="wrap">${bar("Quiz")}<div class="stack">
      <p class="center" style="font-size:1.2rem">⚡ Hör genau hin und finde das richtige Tier so schnell wie möglich!</p>
      <div><p class="label">Auswahl beim Raten</p><div class="seg">${[[10, "10 ähnliche"], [20, "20 ähnliche"], [0, "Alle Tiere"]].map(([v, t]) => `<button data-c="${v}" aria-pressed="${st.choices === v}">${t}</button>`).join("")}</div></div>
      <div><p class="label">Tiere</p><div id="flt"></div><p class="muted" id="cnt"></p></div>
      <label class="switch panel"><span><b>Namen anzeigen</b><br><span class="muted">Ohne Namen ist es schwerer.</span></span><input type="checkbox" id="names" ${st.names ? "checked" : ""}></label>
      ${best ? `<p class="center" style="color:#E08A00;font-weight:900">🏆 Rekord: ${best} Punkte</p>` : ""}
      <button class="big" style="--c:${Q}" id="go">▶ Los geht's</button></div></div>`;
    $app.querySelectorAll(".seg button").forEach(b => b.onclick = () => { st.choices = +b.dataset.c; store.set("quizChoices", st.choices); setup(); });
    const cnt = () => { $app.querySelector("#cnt").textContent = `${poolOf(st).length} Tiere zur Auswahl`; $app.querySelector("#go").disabled = poolOf(st).length < 2; };
    $app.querySelector("#flt").append(filterChips(st, cnt)); cnt();
    $app.querySelector("#names").onchange = (e) => { st.names = e.target.checked; };
    $app.querySelector("#go").onclick = () => { rounds = []; score = 0; streak = 0; next(); };
  };
  const next = () => {
    if (rounds.length >= ROUNDS) return results();
    const pool = poolOf(st), used = new Set(rounds.map(r => r.answer.id));
    const answer = pick(pool.filter(a => !used.has(a.id)).length ? pool.filter(a => !used.has(a.id)) : pool);
    const shown = st.choices ? similar(answer, pool, st.choices) : pool;
    rounds.push({ answer, shown, picked: null, t0: Date.now() });
    draw(); play(answer);
  };
  const draw = () => {
    const r = rounds[rounds.length - 1], done = !!r.picked;
    const grouped = !st.choices;
    const cats = DATA.categories.filter(c => r.shown.some(a => a.category === c.id));
    const tileFor = (a) => {
      let cls = "";
      if (done) cls = a.id === r.answer.id ? "right" : a.id === r.picked.id ? "wrong" : "dim";
      return tile(a, { name: st.names || done, live: false }).replace('class="tile"', `class="tile ${cls}"`)
        .replace("</button>", (done && (a.id === r.answer.id || a.id === r.picked.id)) ? `<span class="mark">${a.id === r.answer.id ? "✅" : "❌"}</span></button>` : "</button>");
    };
    $app.innerHTML = `<div class="wrap">${bar("Quiz")}
      <div class="stats"><span>Runde ${rounds.length}/${ROUNDS}</span><span>${streak >= 2 ? `🔥${streak} · ` : ""}${score} Punkte</span></div>
      <button class="replay" id="rp">↻ Nochmal hören</button>
      ${grouped ? `<div class="chips">${cats.map(c => `<button class="chip" style="--c:${c.color}" data-jump="${c.id}">${esc(c.name)}</button>`).join("")}</div>
        ${cats.map(c => `<div class="sec" id="q-${c.id}" style="--c:${c.color}"><span class="ic">${EMOJI[c.id] || ""}</span><div><b>${esc(c.name)}</b></div></div><div class="grid small">${r.shown.filter(a => a.category === c.id).map(tileFor).join("")}</div>`).join("")}`
      : `<div class="grid">${r.shown.map(tileFor).join("")}</div>`}
      ${done ? `<div class="feedback">${popOut(r.answer)}<div><b style="color:${r.picked.id === r.answer.id ? "var(--good)" : "var(--bad)"}">${r.picked.id === r.answer.id ? `Richtig! +${last}` : `Das war: ${esc(r.answer.name)}`}</b><button class="txtlink" id="inf">Infos zum Tier</button></div><button class="go" id="nx">${rounds.length === ROUNDS ? "Ergebnis" : "Weiter ⏭"}</button></div>` : ""}
    </div>`;
    $app.querySelector("#rp").onclick = () => play(r.answer);
    $app.querySelectorAll("[data-jump]").forEach(b => b.onclick = () => document.getElementById("q-" + b.dataset.jump).scrollIntoView({ behavior: "smooth" }));
    if (!done) $app.querySelectorAll(".tile").forEach(t => t.onclick = () => answer(byId(t.dataset.id)));
    else {
      $app.querySelector("#nx").onclick = next;
      $app.querySelector("#inf").onclick = () => showCard(r.answer);
      if (r.picked.id !== r.answer.id) $app.querySelector(`.tile[data-id="${r.answer.id}"]`)?.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  };
  const answer = (a) => {
    const r = rounds[rounds.length - 1];
    r.picked = a;
    if (a.id === r.answer.id) {
      const s = (Date.now() - r.t0) / 1000;
      last = Math.round(100 * Math.max(0.3, Math.min(1, 1 - (s - 5) / 20 * 0.7))) + Math.min(streak, 5) * 10;
      score += last; streak++;
    } else { streak = 0; last = 0; }
    draw();
  };
  const results = () => {
    stop();
    const right = rounds.filter(r => r.picked?.id === r.answer.id).length;
    const best = store.get("quizBest", 0), record = score > best;
    if (record) store.set("quizBest", score);
    $app.innerHTML = `<div class="wrap">${bar("Quiz")}<div class="stack center">
      <div style="font-size:4rem">${right >= 8 ? "🏆" : right >= 5 ? "⭐️" : "👍"}</div>
      <h2 style="font-size:2.6rem;margin:0">${score} Punkte</h2><p style="margin:0">${right} von ${ROUNDS} richtig</p>
      ${record ? `<p style="color:#E08A00;font-weight:900;margin:0">✨ Neuer Rekord!</p>` : ""}
      <div class="stack" style="gap:8px;text-align:left">${rounds.map(r => `<button class="mode" data-id="${r.answer.id}" style="padding:8px 12px"><span style="width:52px;flex:none">${popOut(r.answer)}</span><span style="flex:1"><b style="font-size:1rem">${esc(r.answer.name)}</b>${r.picked.id !== r.answer.id ? `<span>getippt: ${esc(r.picked.name)}</span>` : ""}</span><span>${r.picked.id === r.answer.id ? "✅" : "❌"}</span></button>`).join("")}</div>
      <div class="row"><button class="big gray" id="set">Einstellungen</button><button class="big" style="--c:${Q}" id="again">↻ Nochmal</button></div></div></div>`;
    $app.querySelectorAll(".mode").forEach(b => b.onclick = () => showCard(byId(b.dataset.id)));
    $app.querySelector("#set").onclick = setup;
    $app.querySelector("#again").onclick = () => { rounds = []; score = 0; streak = 0; next(); };
  };
  setup();
}

/* ---------- Sag's laut! (browser speech recognition, German) ---------- */
const norm = (s) => s.toLowerCase().replace(/ß/g, "ss").normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/-/g, "").replace(/[^a-z ]/g, "");
const namesOf = (a) => [a.name, ...(a.say || [])].map(norm).map(s => s.replace(/ /g, ""));
function lev(a, b) { const d = Array.from({ length: b.length + 1 }, (_, i) => i); for (let i = 1; i <= a.length; i++) { let p = d[0]; d[0] = i; for (let j = 1; j <= b.length; j++) { const t = d[j]; d[j] = Math.min(d[j] + 1, d[j - 1] + 1, p + (a[i - 1] === b[j - 1] ? 0 : 1)); p = t; } } return d[b.length]; }
function verdict(texts, ans, pool) {
  const toks = new Set();
  texts.forEach(t => { const w = norm(t).split(" ").filter(Boolean); w.forEach((x, i) => { toks.add(x); if (w[i + 1]) toks.add(x + w[i + 1]); if (w[i + 2]) toks.add(x + w[i + 1] + w[i + 2]); }); });
  const target = namesOf(ans);
  for (const t of toks) for (const n of target) { const m = Math.max(t.length, n.length); if (t === n || (m >= 5 && Math.abs(t.length - n.length) <= 2 && lev(t, n) <= (m >= 8 ? 2 : 1))) return { kind: "right" }; }
  for (const t of toks) if (t.length >= 3) for (const n of target) if (n.endsWith(t) && n !== t) return { kind: "close" };
  for (const a of pool) if (a.id !== ans.id) for (const n of namesOf(a)) if (toks.has(n)) return { kind: "wrong", other: a };
  return null;
}
function voice() {
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  const V = "#8E5BB5", ROUNDS = 10;
  const st = { cats: new Set(), birds: false };
  let rounds = [], score = 0, rec = null, listening = false;
  const stopRec = () => { listening = false; try { rec && rec.abort(); } catch {} rec = null; };
  cleanup = stopRec;
  const setup = () => {
    $app.innerHTML = `<div class="wrap">${bar("Sag's laut!")}<div class="stack">
      <p class="center" style="font-size:1.2rem">🎤 Du hörst ein Tier, aber du siehst es nicht. Sag einfach laut, welches Tier das ist!</p>
      <p class="center muted">Zum Beispiel „Kuh“, „Amsel“ oder „Buckelwal“. Es reicht auch „Pinguin“ oder „Wal“.</p>
      <div><p class="label">Tiere</p><div id="flt"></div></div>
      ${SR ? "" : `<p class="panel">Dieser Browser kann leider keine Sprache erkennen. Probier es in Safari oder Chrome.</p>`}
      <button class="big" style="--c:${V}" id="go" ${SR ? "" : "disabled"}>▶ Los geht's</button></div></div>`;
    $app.querySelector("#flt").append(filterChips(st, () => {}));
    $app.querySelector("#go").onclick = () => { rounds = []; score = 0; next(); };
  };
  const listen = (r) => {
    stopRec();
    rec = new SR(); rec.lang = "de-DE"; rec.interimResults = true; rec.continuous = true; rec.maxAlternatives = 5;
    rec.onresult = (e) => {
      const texts = []; let shown = "";
      for (let i = e.resultIndex; i < e.results.length; i++) { for (const alt of e.results[i]) texts.push(alt.transcript); shown += e.results[i][0].transcript; }
      const h = $app.querySelector("#heard"); if (h) h.textContent = shown ? `„${shown.trim()}“` : "";
      const v = verdict(texts, r.answer, poolOf(st));
      if (!v) return;
      if (v.kind === "wrong") { r.wrong = true; const w = $app.querySelector("#wrong"); if (w) w.textContent = `${v.other.name}? Nein, versuch's nochmal!`; }
      else reveal(v.kind);
    };
    rec.onerror = (e) => { if (e.error === "not-allowed") { const w = $app.querySelector("#wrong"); if (w) w.textContent = "Bitte erlaube das Mikrofon in den Browser-Einstellungen."; } };
    rec.onend = () => { if (listening) { try { rec.start(); } catch {} } };
    listening = true;
    try { rec.start(); } catch {}
    const m = $app.querySelector("#mys"); if (m) m.classList.add("listening");
  };
  const next = () => {
    if (rounds.length >= ROUNDS) return results();
    const pool = poolOf(st), used = new Set(rounds.map(r => r.answer.id));
    const answer = pick(pool.filter(a => !used.has(a.id)).length ? pool.filter(a => !used.has(a.id)) : pool);
    const r = { answer, t0: Date.now(), result: null, wrong: false, pts: 0 };
    rounds.push(r);
    $app.innerHTML = `<div class="wrap">${bar("Sag's laut!")}<div class="stats"><span>Runde ${rounds.length}/${ROUNDS}</span><span>${score} Punkte</span></div>
      <div class="stack center" style="--c:${V}"><button class="mystery" id="mys">?</button>
      <h2 style="font-size:1.8rem;margin:0">Welches Tier ist das?</h2><div>🎤 Ich höre zu …</div>
      <div class="heard" id="heard"></div><div id="wrong" style="color:var(--bad);font-weight:800;min-height:1.2em"></div>
      <div class="row"><button class="big gray" id="again">↻ Nochmal hören</button><button class="big" style="--c:${V}" id="give">👁 Weiß nicht</button></div></div></div>`;
    const mys = $app.querySelector("#mys");
    onPlayChange.clear(); onPlayChange.add(() => { mys.textContent = playingId === answer.id ? "🔊" : "?"; });
    mys.onclick = $app.querySelector("#again").onclick = () => play(answer);
    $app.querySelector("#give").onclick = () => reveal("gave");
    play(answer); listen(r);
  };
  const reveal = (kind) => {
    stopRec();
    const r = rounds[rounds.length - 1]; if (r.result) return;
    r.result = kind;
    if (kind !== "gave") {
      const s = (Date.now() - r.t0) / 1000;
      r.pts = Math.round(100 * Math.max(0.3, Math.min(1, 1 - (s - 4) / 12 * 0.7))) - (kind === "close" ? 20 : 0) - (r.wrong ? 20 : 0);
      score += r.pts;
    }
    const a = r.answer;
    onPlayChange.clear();
    $app.innerHTML = `<div class="wrap">${bar("Sag's laut!")}<div class="stats"><span>Runde ${rounds.length}/${ROUNDS}</span><span>${score} Punkte</span></div>
      <div class="stack center"><div style="max-width:360px;margin:0 auto;width:100%" id="pic">${popOut(a, .32)}</div>
      <h2 style="font-size:2.2rem;margin:0">${esc(a.name)}</h2>
      <p style="font-weight:900;font-size:1.2rem;margin:0;color:${kind === "gave" ? "#E07A27" : "var(--good)"}">${kind === "right" ? `✅ Richtig! +${r.pts}` : kind === "close" ? `✅ Fast genau! Es ist ein ${esc(a.name)}. +${r.pts}` : `💡 Das war: ${esc(a.name)}`}</p>
      <button class="txtlink" id="more">ⓘ Mehr über das Tier</button>
      <button class="big" style="--c:${V}" id="nx">${rounds.length >= ROUNDS ? "Ergebnis" : "⏭ Nächstes Tier"}</button></div></div>`;
    $app.querySelector("#pic").onclick = () => toggle(a);
    $app.querySelector("#more").onclick = () => showCard(a);
    $app.querySelector("#nx").onclick = next;
    play(a);
  };
  const results = () => {
    stop();
    const right = rounds.filter(r => r.result === "right" || r.result === "close").length;
    $app.innerHTML = `<div class="wrap">${bar("Sag's laut!")}<div class="stack center"><div style="font-size:4rem">${right >= 8 ? "🏆" : right >= 5 ? "⭐️" : "👍"}</div>
      <h2 style="font-size:2.6rem;margin:0">${score} Punkte</h2><p>${right} von ${ROUNDS} erkannt</p>
      <div class="row"><button class="big gray" id="set">Einstellungen</button><button class="big" style="--c:${V}" id="again">↻ Nochmal</button></div></div></div>`;
    $app.querySelector("#set").onclick = setup;
    $app.querySelector("#again").onclick = () => { rounds = []; score = 0; next(); };
  };
  setup();
}

/* ---------- credits ---------- */
function credits() {
  const line = (kind, m) => m ? `<div class="credit">${kind}${m.edited ? ` (${esc(m.edited)})` : ""}: ${esc(m.artist || "unbekannt")}, ${esc(m.license || "")} – <a href="${esc(m.page)}" target="_blank" rel="noopener">Quelle</a></div>` : "";
  $app.innerHTML = `<div class="wrap">${bar("Nachweise")}<div class="credits-list">
    <p class="panel">Alle Fotos und Tonaufnahmen stammen von Wikimedia Commons und stehen unter freien Lizenzen (gemeinfrei, CC0, CC BY oder CC BY-SA). Die Tiere wurden aus den Fotos freigestellt und verkleinert, Tonaufnahmen gekürzt und in der Lautstärke angeglichen. Gefährdungsstatus: IUCN Rote Liste über Wikidata (CC0).</p>
    ${DATA.categories.map(c => `<h3>${esc(c.name)}</h3>${DATA.animals.filter(a => a.category === c.id).map(a => `<div class="panel"><b>${esc(a.name)}</b>${line("Foto", a.credits.image)}${line("Ton", a.credits.sound)}</div>`).join("")}`).join("")}
  </div></div>`;
}

/* ---------- start ---------- */
fetch("animals.json").then(r => r.json()).then(d => {
  DATA = d;
  CAT = Object.fromEntries(d.categories.map(c => [c.id, c]));
  route();
}).catch(() => { $app.innerHTML = `<p class="loading">Die Tiere konnten nicht geladen werden. Bitte Seite neu laden.</p>`; });
