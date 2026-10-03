window.addEventListener("load", () => setTimeout(() => {
  const out = [];
  const t = (name, fn) => { try { document.getElementById("c-reset").click(); state.sheet = null; state.system = null; state.alert = null; render(); const r = fn(); out.push([r === true ? "PASS" : "FAIL", name, r === true ? "" : String(r)]); } catch (e) { out.push(["ERROR", name, e.message]); } };
  const clear = () => { state.sheet = null; state.system = null; state.alert = null; for (const k of Object.keys(state.stacks)) state.stacks[k] = []; };
  const fresh = () => { state.tab = "now"; state.sheet = null; state.system = null; for (const k of Object.keys(state.stacks)) state.stacks[k] = []; render(); };
  fresh();

  t("1 no full swipe: release past 60% leaves the occurrence nudging and the tile open", () => {
    const row = main.querySelector(".swipe-row"); if (!row) return "no swipe row on Now";
    const id = row.parentElement.querySelector(".trail").dataset.ack;
    const w = row.offsetWidth || 300;
    swipe = { row, x0: 0, y0: 0, base: 0, x: -w * 0.9, id: 1, active: true };
    endSwipe({ type: "pointerup", pointerId: 1 });
    const o = occurrences.find((x) => x.id === id);
    return o.state === "NUDGING" && Number(row.dataset.x) === -SWIPE_OPEN ? true : `state ${o.state}, x ${row.dataset.x}`;
  });
  fresh();
  const threeCards = () => {
    if (!occurrences.some((o) => o.id === "oT3")) { const base = occurrences.find((o) => o.state === "NUDGING"); occurrences.push({ ...base, id: "oT3", reminderId: "r10", events: [] }); }
    fresh(); return [...main.querySelectorAll(".nudgecard")];
  };
  t("2a focus after Done on a middle card goes to the card that takes its place", () => {
    const cards = threeCards(); if (cards.length < 3) return `only ${cards.length} cards`;
    const v = cards[1].querySelector("[data-ack]").dataset.ack, want = cards[2].querySelector("[data-open]").textContent;
    const focus = nextFocusAfterAck(v); ack(v); render(); const el = focus();
    return el && !el.hasAttribute("data-ack") && el.textContent === want ? true : (el ? el.outerHTML.slice(0, 90) : "nothing");
  });
  t("2b focus after Done on the last card goes to the one before it", () => {
    const cards = threeCards(); if (cards.length < 2) return `only ${cards.length} cards`;
    const v = cards[cards.length - 1].querySelector("[data-ack]").dataset.ack, want = cards[cards.length - 2].querySelector("[data-open]").textContent;
    const focus = nextFocusAfterAck(v); ack(v); render(); const el = focus();
    return el && el.textContent === want ? true : (el ? el.outerHTML.slice(0, 90) : "nothing");
  });
  t("2c My Day: Done on a reminder's second row today keeps focus on that row", () => {
    const r = remById("r6"); r.rrule = "FREQ=DAILY;BYTIME=06:00,08:00"; r.dtstart = "2026-09-01T06:00";
    const base = occurrences.find((o) => o.state === "NUDGING");
    occurrences.push({ ...base, id: "oT4", reminderId: "r6", scheduledFor: "2026-09-28T08:00", events: [] });
    state.tab = "day"; nav();
    const btn = main.querySelector('[data-ack="oT4"]:not(.swipe-act)'); if (!btn) return "no nudging 8:00 row for r6";
    const rows = [...main.querySelectorAll('[data-open="r6"]')]; if (rows.length < 2) return `r6 has ${rows.length} row(s)`;
    const li = btn.closest("li"), ul = li.parentElement, ulIdx = [...main.querySelectorAll("ul")].indexOf(ul), idx = [...ul.children].indexOf(li);
    const focus = nextFocusAfterAck("oT4", btn); ack("oT4"); render(); const el = focus();
    const li2 = main.querySelectorAll("ul")[ulIdx]?.children[idx];
    return el && li2 && li2.contains(el) ? true : (el ? "focused " + (el.closest("li")?.textContent.replace(/\s+/g, " ").slice(0, 40)) : "nothing");
  });
  t("2d Assistive Access: Done on the last card goes to the one before, else the Now header", () => {
    state.assistive = true; clear(); render(); const cards = [...main.querySelectorAll(".aa-card")]; if (!cards.length) { state.assistive = false; render(); return "no AA cards"; }
    const last = cards[cards.length - 1], btn = last.querySelector("[data-ack]"), want = cards.length > 1 ? cards[cards.length - 2].querySelector(".aa-title") : null;
    const focus = nextFocusAfterAck(btn.dataset.ack, btn); ack(btn.dataset.ack); render(); const el = focus();
    const ok = want ? el?.textContent === want.textContent && el.classList.contains("aa-title") : el?.id === "aa-now"; state.assistive = false; render();
    return ok ? true : (el ? el.outerHTML.slice(0, 90) : "nothing");
  });
  t("2e My Day filtered to Nudging: Done on the last row focuses the row before, not a marker or the title", () => {
    state.tab = "day"; state.dayStatus = "nudging"; nav();
    const btns = [...main.querySelectorAll("ul.list > li [data-ack]:not(.swipe-act)")]; if (btns.length < 2) return `only ${btns.length} nudging rows`;
    const btn = btns[btns.length - 1], prevRid = btns[btns.length - 2].closest("li").querySelector("[data-open]").dataset.open;
    const focus = nextFocusAfterAck(btn.dataset.ack, btn); ack(btn.dataset.ack); render(); const el = focus();
    return el?.dataset.open === prevRid ? true : (el ? el.outerHTML.slice(0, 80) : "nothing");
  });
  t("3a banners: alarms off + Time Sensitive off shows two", () => {
    prefs.ios = 26; Object.assign(perm, { notifications: true, alarms: false, timeSensitive: false });
    const n = (permBanner().match(/class="banner/g) || []).length; return n === 2 ? true : `${n} banners`;
  });
  t("3b banners: notifications off shows only that one", () => {
    Object.assign(perm, { notifications: false, alarms: false, timeSensitive: false });
    const b = permBanner(); const n = (b.match(/class="banner/g) || []).length;
    return n === 1 && b.includes("Nudges can't reach you.") ? true : `${n} banners`;
  });
  t("3c Settings statuses use On/Off, no 'Allowed'", () => {
    Object.assign(perm, { notifications: true, alarms: true, timeSensitive: true });
    const h = settingsSections().map((s) => s.body).join("");
    return !h.includes("Allowed") && !h.includes("On · Time Sensitive<") && h.includes(">On<") ? true : "status text differs";
  });
  t("15 Settings footer: with notifications off it only points to iOS Settings", () => {
    Object.assign(perm, { notifications: false }); const h = settingsSections()[0].body;
    const footer = h.match(/<p class="sec-f">([^<]*)<\/p>/)?.[1] || "";
    return footer.trim() === "Change these in iOS Settings." ? true : JSON.stringify(footer.slice(0, 80));
  });
  t("17 no time zone setting anywhere (Settings, form, details)", () => {
    const sett = settingsSections().some((x) => /Time Zone/.test(x.title));
    openEditor(); const form = !!document.getElementById("f-tz"); state.sheet = null; render();
    state.tab = "now"; nav(); main.querySelector("[data-open]").click(); const det = main.innerText.includes("Time Zone");
    return !sett && !form && !det ? true : `settings ${sett}, form ${form}, details ${det}`;
  });
  t("4a Not Done: one-off done 1 h ago is offered", () => {
    const r = { id: "tx1", rrule: null, status: "COMPLETED" };
    occurrences.push({ id: "otx1", reminderId: "tx1", scheduledFor: iso(new Date(NOW - 2 * 36e5)), state: "ACKED", closedAt: iso(new Date(NOW - 36e5)) });
    return latestDone(r)?.id === "otx1" ? true : "not offered";
  });
  t("4b Not Done: one-off done 25 h ago is not offered", () => {
    const r = { id: "tx2", rrule: null, status: "COMPLETED" };
    occurrences.push({ id: "otx2", reminderId: "tx2", scheduledFor: iso(new Date(NOW - 26 * 36e5)), state: "ACKED", closedAt: iso(new Date(NOW - 25 * 36e5)) });
    return latestDone(r) === null ? true : "still offered";
  });
  t("4c Not Done: paused reminder is not offered", () => {
    const r = { id: "tx1", rrule: null, status: "PAUSED" }; return latestDone(r) === null ? true : "offered while paused";
  });
  t("4d Not Done: pause then resume a repeat doesn't bring it back", () => {
    const r = remById("r2"); if (latestDone(r)?.state !== "ACKED") return "precondition: r2 not offered before pause";
    pause("r2"); resume("r2"); return latestDone(remById("r2")) === null ? true : "offered again after resume";
  });
  t("4e Not Done: a one-off given a new time is not offered", () => {
    const r = { id: "tx5", rrule: null, status: "ACTIVE", nextOccurrenceAt: "2026-09-29T09:00" };
    occurrences.push({ id: "otx5", reminderId: "tx5", scheduledFor: iso(new Date(NOW - 2 * 36e5)), state: "ACKED", closedAt: iso(new Date(NOW - 36e5)) });
    return latestDone(r) === null ? true : "still offered";
  });
  t("5a monthly on the 31st falls on 30 Sep", () => {
    const n = nextOccurrence({ dtstart: "2026-01-31T09:00", rrule: "FREQ=MONTHLY;BYMONTHDAY=31" });
    return n && iso(n).startsWith("2026-09-30T09:00") ? true : n && iso(n);
  });
  t("5b yearly on 29 Feb falls on 28 Feb 2027", () => {
    const n = nextOccurrence({ dtstart: "2024-02-29T09:00", rrule: "FREQ=YEARLY" });
    return n && iso(n).startsWith("2027-02-28T09:00") ? true : n && iso(n);
  });
  t("6a new one-off with a past start: error shown and Add disabled", () => {
    state.tab = "now"; openEditor(); state.sheet.draft.title = "Past"; state.sheet.draft.dtstart = "2026-09-28T07:00"; render();
    const err = document.body.innerText.includes("This time has passed. Choose a later time.");
    const btn = document.querySelector("[data-sheet-save]"); const ok = err && btn && btn.disabled; state.sheet = null; render();
    return ok ? true : `error ${err}, disabled ${btn && btn.disabled}`;
  });
  t("6b new one-off in the future: no error, Add enabled", () => {
    openEditor(); state.sheet.draft.title = "Future"; render();
    const err = document.body.innerText.includes("This time has passed."); const btn = document.querySelector("[data-sheet-save]");
    const ok = !err && btn && !btn.disabled; state.sheet = null; render(); return ok ? true : `error ${err}, disabled ${btn && btn.disabled}`;
  });
  t("6c editing a past one-off without changing its time can be saved", () => {
    const r = reminders.find((x) => !x.rrule && L(x.dtstart) <= NOW); if (!r) return "no past one-off in seed data";
    openEditor(r.id); const blocked = pastOneOff(state.sheet.draft); state.sheet = null; render(); return !blocked ? true : "blocked";
  });
  t("6d Resume sheet with the old past time is blocked", () => {
    const r = reminders.find((x) => !x.rrule && L(x.dtstart) <= NOW); openEditor(r.id); state.sheet.resume = true;
    const blocked = pastOneOff(state.sheet.draft); state.sheet = null; render(); return blocked ? true : "not blocked";
  });
  t("6e repeat changed to Never with an old start is blocked", () => {
    const r = reminders.find((x) => x.rrule && L(x.dtstart) <= NOW); openEditor(r.id); state.sheet.draft.repeat = "never";
    const blocked = pastOneOff(state.sheet.draft); state.sheet = null; render(); return blocked ? true : "not blocked";
  });
  t("6f title-only edit of an occurrence past its limit doesn't close it", () => {
    const o = occurrences.find((x) => x.state === "NUDGING"); const r = remById(o.reminderId); const cap = capOf(r);
    const saved = o.attempts; o.attempts = cap.maxAttempts + 1; const res = closesOnEdit(o, r, r.dtstart.slice(0, 16), cap); o.attempts = saved;
    return res === null ? true : `closes: ${res}`;
  });
  t("6g lowering the limit below the nudges sent still closes it", () => {
    const o = occurrences.find((x) => x.state === "NUDGING"); const r = remById(o.reminderId);
    const res = closesOnEdit(o, r, r.dtstart.slice(0, 16), { ...capOf(r), maxAttempts: Math.max(1, o.attempts) });
    return res === "limit" ? true : `got ${res}`;
  });
  t("V1 tag names: one # dropped, end hyphens trimmed, no length limit", () => {
    const long = "a".repeat(45) + "😀";
    const cases = [["#home", "home"], ["##home", "#home"], ["dog ", "dog"], [" -dog walks- ", "dog-walks"], ["dog  walks", "dog-walks"], [long, long]];
    const bad = cases.filter(([i, o]) => cleanTag(i) !== o).map(([i, o]) => `${JSON.stringify(i).slice(0, 20)}->${JSON.stringify(cleanTag(i)).slice(0, 20)}`);
    return bad.length ? bad.join("; ") : true;
  });
  t("V2 tag fields have no maxlength; # dropped and spaces hyphenated as you type, caret kept", () => {
    const f = document.createElement("input"); document.body.appendChild(f);
    f.value = "#home"; f.setSelectionRange(5, 5); shapeTagField(f); const a = f.value === "home" && f.selectionStart === 4;
    f.value = "dog walks"; f.setSelectionRange(4, 4); shapeTagField(f); const b = f.value === "dog-walks" && f.selectionStart === 4; f.remove();
    openEditor(); state.sheet.page = "tags"; render(); const nt = document.getElementById("f-newtag"); const lim = nt?.getAttribute("maxlength"); state.sheet = null; render();
    return a && b && nt && lim === null ? true : `hash ${a}, space ${b}, maxlength ${lim}`;
  });
  t("R9 saving the Resume sheet with a repeat and a past start resumes it", () => {
    const r = reminders.find((x) => !x.rrule && L(x.dtstart) <= NOW); if (!r) return "no past one-off";
    pause(r.id); openEditor(r.id); state.sheet.resume = true; state.sheet.draft.repeat = "daily"; saveFromSheet();
    const r2 = remById(r.id); return r2.status === "ACTIVE" && r2.nextOccurrenceAt && L(r2.nextOccurrenceAt) > NOW ? true : `status ${r2.status}, next ${r2.nextOccurrenceAt}`;
  });
  t("R10 editing a paused reminder's schedule leaves it without a next time", () => {
    const r = reminders.find((x) => x.rrule && x.status === "ACTIVE" && !openOccs().some((o) => o.reminderId === x.id)); pause(r.id);
    updateReminder(r, { ...r, dtstart: "2026-10-05T10:00", rrule: "FREQ=DAILY" });
    const r2 = remById(r.id); return r2.status === "PAUSED" && !r2.nextOccurrenceAt ? true : `status ${r2.status}, next ${r2.nextOccurrenceAt}`;
  });
  t("7 history: no engine level, alarm stop wording", () => {
    const a = EVENT_TEXT.NUDGE_SENT({ attempt: 2, level: 1, priority: 3 }), b = EVENT_TEXT.ACKED({ from: "alarm" });
    return !a.includes("level") && b === "Done (alarm stopped)" ? true : `${a} | ${b}`;
  });
  t("7b every Done source the mockup can produce maps to its approved string", () => {
    const want = { alarm: "Done (alarm stopped)", liveActivity: "Done from the Lock Screen", notification: "Done from the notification", assistiveAccess: "Done in Assistive Access", undefined: "Done" };
    const bad = Object.entries(want).filter(([k, v]) => EVENT_TEXT.ACKED({ from: k === "undefined" ? undefined : k }) !== v).map(([k]) => k);
    return bad.length ? "wrong: " + bad.join(", ") : true;
  });
  t("7c Assistive Access Done button carries its source", () => {
    state.assistive = true; fresh(); const b = main.querySelector(".aa-btn[data-ack]"); state.assistive = false; fresh();
    return b?.dataset.src === "assistiveAccess" ? true : (b ? "no data-src" : "no AA Done button");
  });
  t("8 'Due' status reads Coming up", () => STATUS_LABEL.DUE === "Coming up" ? true : STATUS_LABEL.DUE);
  t("9 Delete All Data clears Recent Searches", () => { state.recent = ["rent"]; wipeAll(); return state.recent.length === 0 ? true : "recent kept"; });

  const pre = document.createElement("pre"); pre.id = "TESTRESULTS"; pre.textContent = JSON.stringify(out); document.body.appendChild(pre);
}, 50));
