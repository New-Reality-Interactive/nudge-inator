#!/usr/bin/env python3
"""Screenshots of a mockup's screens in headless Chrome, named as scripts/screenshots.sh names the
app's, so each pair can be compared (scripts/contact-sheet.sh). The screens are the mockup
template's (docs/mockups/*-mockup-template), so a version or change mockup copied from it keeps
working. A screen it doesn't know is added to SCREENS: the JavaScript that shows it in the mockup, and how many
pages.

Usage: scripts/mockup-shots.py <mockup folder> <out folder> [screen ...]
Writes <out>/<portrait|landscape|largest-text>/<screen>[-<page>].png. Needs Google Chrome.
"""
import os, subprocess, sys, tempfile, urllib.parse

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Runs the snippet in the page's URL hash once the mockup has loaded.
HOOK = """
if (location.hash.length > 1) { try { (0, eval)(decodeURIComponent(location.hash.slice(1))); } catch (e) { document.body.prepend(String(e)); } }
</script>"""
# Scrolls the top layer (a sheet, or the screen) down by k screens.
SCROLL = """function __scroll(k){const top=document.getElementById('sheet').innerHTML.trim()?document.getElementById('sheet'):main;
const els=[top,...top.querySelectorAll('*')].filter(e=>e.scrollHeight>e.clientHeight+4&&getComputedStyle(e).overflowY!='visible');
els.forEach(e=>{e.scrollTop=k*e.clientHeight*0.8});}"""
# Screen name: (JavaScript that shows it, pages to scroll through).
SCREENS = {
  "now": ("", 3),
  "details-nudging": ("push({kind:'rem',id:'r1'})", 4),
  "form-edit-locked": ("openEditor('r1')", 4),
  "details-coming-up": ("push({kind:'rem',id:'r3'})", 4),
  "myday": ("state.tab='day';nav()", 3),
  "myday-filter": ("state.tab='day';nav();openDayFilter()", 1),
  "tags": ("state.tab='tags';nav()", 2),
  "tag-home": ("state.tab='tags';nav();push({kind:'tag',id:'home'})", 2),
  "tags-edit": ("state.tab='tags';state.tagEdit=true;nav()", 1),
  "tag-new": ("state.tab='tags';nav();openTagSheet()", 1),
  "settings": ("state.tab='settings';nav()", 3),
  "settings-how-it-nudges": ("state.tab='settings';nav();push({kind:'hin'})", 4),
  "form-new": ("openEditor()", 4),
  "form-tags": ("openEditor();state.sheet.page='tags';render()", 1),
  "form-repeat": ("openEditor();document.querySelector('[data-sheet-page=repeat]').click()", 2),
  "form-custom": ("openEditor();document.querySelector('[data-sheet-page=repeat]').click();document.querySelector('[data-repeat=custom]').click()", 3),
  "onboarding": ("state.sheet={kind:'onboard'};render()", 1),
  "banner-notifications-off": ("perm.notifications=false;render()", 4),
  "settings-notifications-off": ("perm.notifications=false;state.tab='settings';nav()", 2),
  "banner-alarms-off": ("perm.alarms=false;render()", 3),
  "settings-alarms-off": ("perm.alarms=false;state.tab='settings';nav()", 1),
  "banner-time-sensitive-off": ("perm.timeSensitive=false;render()", 1),
  # Settings' Badges row (icon-badge #85). A mockup without it draws Settings with no Badges row.
  "settings-badges-off": ("perm.badges='denied';state.tab='settings';nav()", 2),
  "settings-badges-not-set": ("perm.badges='notDetermined';state.tab='settings';nav()", 2),
  # Pace and strength (enhancement-pace).
  "details-relentless": ("push({kind:'rem',id:'r7'})", 4),
  "form-new-escalating": ("openEditor();state.sheet.draft.pace='escalating';render()", 4),
  "form-new-consistent": ("openEditor();state.sheet.draft.pace='consistent';state.sheet.draft.wait=10;render()", 4),
  "form-new-relentless": ("openEditor();state.sheet.draft.strength='relentless';render()", 4),
  # The Filter button's badge at counts the seed can't reach.
  "myday-badge-12": ("prefs.badgeCount='12';state.tab='day';state.dayFilter.ids=[tags[0].id];nav()", 1),
  "myday-badge-999": ("prefs.badgeCount='999';state.tab='day';state.dayFilter.ids=[tags[0].id];nav()", 1),
  # Six tags in the tokens' three rows, and the
  # Filter button's menu with them chosen.
  "myday-tokens-6": ("state.tab='day';state.dayFilter.ids=tags.slice(0,6).map(t=>t.id);nav()", 1),
  "myday-filter-menu": ("state.tab='day';state.dayFilter.ids=tags.slice(0,6).map(t=>t.id);nav();showFilterMenu(document.querySelector('[data-dayfilter]'))", 1),
  # The filter sheet with one tag (Match disabled) and two (Match working).
  "myday-filter-1": ("state.tab='day';state.dayFilter.ids=sortTags(tags).slice(0,1).map(t=>t.id);nav();openDayFilter()", 1),
  "myday-filter-2": ("state.tab='day';state.dayFilter.ids=sortTags(tags).slice(0,2).map(t=>t.id);nav();openDayFilter()", 1),
  "settings-default-pace": ("state.tab='settings';nav();push({kind:'defpace'})", 1),
  "settings-how-it-nudges-escalating": ("settings.defaultPace={pace:'escalating',wait:10};state.tab='settings';nav();push({kind:'hin'})", 4),
  # Settings' About page.
  "settings-about": ("state.tab='settings';nav();push({kind:'about'})", 2),
}
# Variant: JavaScript that sets it up.
VARIANTS = {"portrait": "", "landscape": "setOrientation(true);", "largest-text": "document.documentElement.dataset.type='ax5';"}


def main():
    mockup, out, only = sys.argv[1], sys.argv[2], set(sys.argv[3:])
    html = open(os.path.join(mockup, "index.html")).read()
    end = html.rindex("</script>")
    copy = os.path.join(tempfile.mkdtemp(), "index.html")
    with open(copy, "w") as f:
        f.write(html[:end] + HOOK + html[end + len("</script>"):])
    for variant, setup in VARIANTS.items():
        folder = os.path.join(out, variant)
        os.makedirs(folder, exist_ok=True)
        width, height = (960, 520) if variant == "landscape" else (520, 960)
        for name, (show, pages) in SCREENS.items():
            if only and name not in only:
                continue
            for page in range(pages):
                suffix = f"-{page + 1}" if pages > 1 else ""
                # Light, as scripts/screenshots.sh sets the simulators, whatever this Mac's appearance.
                code = (SCROLL + "document.documentElement.dataset.theme='light';"
                        + "document.querySelector('aside').style.display='none';" + setup
                        + f"setDevice(device.id);render();{show};render();setTimeout(()=>__scroll({page}),50)")
                subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                                "--virtual-time-budget=2000", f"--screenshot={folder}/{name}{suffix}.png",
                                f"--window-size={width},{height}", f"file://{copy}#" + urllib.parse.quote(code)],
                               capture_output=True)
    print(out)


main()
