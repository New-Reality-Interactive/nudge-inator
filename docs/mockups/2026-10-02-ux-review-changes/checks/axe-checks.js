window.addEventListener("load", () => setTimeout(async () => {
  const set = (id, v) => { const el = document.getElementById(id); if (el.type === "checkbox") el.checked = v; else el.value = v; el.dispatchEvent(new Event("change")); };
  const clear = () => { state.sheet = null; state.system = null; state.alert = null; for (const k of Object.keys(state.stacks)) state.stacks[k] = []; };
  const tab = (t) => { clear(); state.tab = t; nav(); };
  const SCREENS = {
    now: () => tab("now"), myday: () => tab("day"), tags: () => tab("tags"), search: () => tab("search"), settings: () => tab("settings"),
    details: () => { tab("now"); main.querySelector("[data-open]").click(); },
    form: () => { tab("now"); openEditor(); },
    welcome: () => { tab("now"); state.sheet = { kind: "onboard", ret: null }; render(); },
    dayfilter: () => { tab("day"); openDayFilter(); },
  };
  const found = {}; let runs = 0; const errors = [];
  for (const ios of ["18", "26", "27"]) for (const theme of ["light", "dark"]) for (const ic of [false, true]) for (const type of ["", "ax3"]) {
    set("c-ios", ios); set("c-theme", theme); set("c-contrast", ic); set("c-type", type);
    for (const [name, open] of Object.entries(SCREENS)) {
      try {
        open(); await new Promise((r) => setTimeout(r, 30));
        const res = await axe.run(document, { runOnly: { type: "tag", values: ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22a", "wcag22aa"] }, resultTypes: ["violations"] });
        runs++;
        for (const v of res.violations) {
          const key = `${v.id} (${v.impact}): ${v.help}`;
          const f = (found[key] ??= { count: 0, where: new Set(), tags: v.tags.filter((t) => t.startsWith("wcag")).join(","), sample: v.nodes[0]?.target.join(" ") + " — " + (v.nodes[0]?.failureSummary || "").replace(/\s+/g, " ").slice(0, 200) });
          f.count += v.nodes.length; f.where.add(`${name}@iOS${ios}/${theme}${ic ? "/IC" : ""}${type ? "/" + type : ""}`);
        }
      } catch (e) { errors.push(`${name}@${ios}/${theme}/${ic}/${type}: ${e.message}`); }
    }
  }
  const out = { runs, errors, violations: Object.fromEntries(Object.entries(found).map(([k, f]) => [k, { count: f.count, configs: f.where.size, tags: f.tags, examples: [...f.where].slice(0, 6), sample: f.sample }])) };
  const pre = document.createElement("pre"); pre.id = "AXERESULTS"; pre.textContent = JSON.stringify(out); document.body.appendChild(pre);
}, 50));
