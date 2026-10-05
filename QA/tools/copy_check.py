#!/usr/bin/env python3
"""Exact-copy check: every normative string in the spec tables must exist verbatim in the shipped content
(content/*.json in the repo AND inside the APK's embedded content)."""
import re, json, sys, pathlib, zipfile
root = pathlib.Path(__file__).resolve().parents[2]
spec = (root/"CASE_ZERO_Vertical_Slice_BG.md").read_text(encoding="utf-8")
def strings(obj, out):
    if isinstance(obj, str): out.append(obj)
    elif isinstance(obj, dict): [strings(v, out) for v in obj.values()]
    elif isinstance(obj, list): [strings(v, out) for v in obj]
def corpus(read):
    out=[]
    for f in ["manifest.json","ui_text.json","cases/C01.json","cases/C02.json","cases/C03.json"]:
        strings(json.loads(read(f)), out)
    return out
norm = lambda s: re.sub(r"\s+"," ",s.replace("„","").replace("“","").replace("”","").replace('"',"")).strip()
sources = {"repo": corpus(lambda f:(root/"content"/f).read_text(encoding="utf-8"))}
for apk in ("dev","playtest"):
    z=zipfile.ZipFile(root/f"qa/apk/casezero-{apk}-0.1.0.apk")
    sources[apk]=corpus(lambda f,z=z:z.read("assets/content/"+f).decode("utf-8"))
blob = {k:norm("\n".join(v)) for k,v in sources.items()}
need=[]
for m in re.finditer(r"^\| Result / exact detail copy \| (.+?) \|$", spec, re.M):
    parts = re.split(r"\s*При (?:EMPTY|RESTORED): ", m.group(1)) if "При EMPTY:" in m.group(1) else [m.group(1)]
    for part in [x for x in parts if x]: need.append(("detail", part))
for m in re.finditer(r"^\| (EV_C0\d_[A-Z_]+) \|[^|]*\|[^|]*\|[^|]*\|[^|]*\|[^|]*\| ([^|]+?) \| (?:YES|NO) \|$", spec, re.M): need.append((m.group(1),m.group(2)))
for m in re.finditer(r"^\| (C0\d_Q\d_A\d) \| ([^|]+?) \| (?:CORRECT|INCORRECT) \|$", spec, re.M): need.append((m.group(1),m.group(2)))
for m in re.finditer(r"^\| (C0\d_H\d) \| ([^|]+?) \|$", spec, re.M): need.append((m.group(1),m.group(2)))
for m in re.finditer(r"^\| (Correct feedback|Incorrect feedback|Question) \| ([^|]+?) \|$", spec, re.M): need.append((m.group(1),m.group(2)))
for m in re.finditer(r"^Opening text: (.+)$", spec, re.M): need.append(("opening",m.group(1)))
for m in re.finditer(r"^12\. SOLVED: (.+?); tap", spec, re.M): need.append(("solved",m.group(1)))
missing={k:[] for k in blob}
for kind,t in need:
    n=norm(t)
    for k in blob:
        if n not in blob[k]: missing[k].append((kind,t))
print(f"normative strings checked: {len(need)}")
for k,v in missing.items():
    print(f"{k}: missing {len(v)}")
    for kind,t in v[:12]: print("   -",kind,"|",t[:110])
sys.exit(1 if any(missing.values()) else 0)
