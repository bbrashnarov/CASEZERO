#!/usr/bin/env python3
"""Static re-verification of numeric claims in CASE_ZERO_Vertical_Slice_BG.md.
Parses scene registers + per-object tables; checks centers, normalized centers,
hitbox>=sprite, bounds, pairwise overlaps, min size, evidence/asset cross-refs."""
import re, sys, itertools, pathlib
SPEC = pathlib.Path(__file__).resolve().parents[2] / "CASE_ZERO_Vertical_Slice_BG.md"
txt = SPEC.read_text(encoding="utf-8")
lines = txt.splitlines()
fail = 0
def bad(msg):
    global fail; fail += 1; print("FAIL:", msg)
def ok(msg): print("ok  :", msg)

nums = lambda s: [int(x) for x in re.findall(r"-?\d+", s)]
# ---- scene registers: | C0X_ID | name | [x,y,w,h] | (cx, cy) | (nx, ny) | [hitbox|NONE] | z |
reg = {}
row = re.compile(r"^\|\s*(C0[123]_[A-Z]+)\s*\|[^|]*\|\s*\[([^\]]+)\]\s*\|\s*\(([^)]+)\)\s*\|\s*\(([^)]+)\)\s*\|\s*(\[[^\]]+\]|NONE)\s*\|\s*(\d+)\s*\|")
for l in lines:
    m = row.match(l)
    if m:
        oid = m.group(1)
        reg[oid] = dict(rect=nums(m.group(2)), center=nums(m.group(3)),
                        norm=[float(x) for x in m.group(4).split(",")],
                        hit=None if m.group(5)=="NONE" else nums(m.group(5)), z=int(m.group(6)))
print(f"parsed {len(reg)} scene objects")
VP = (0, 264, 1080, 1332)  # scene viewport
for oid, o in reg.items():
    x,y,w,h = o["rect"]
    if o["center"] != [x+w//2, y+h//2]: bad(f"{oid} center {o['center']} != {[x+w//2,y+h//2]}")
    cx,cy = o["center"]
    if abs(o["norm"][0]-cx/1080)>5e-7 or abs(o["norm"][1]-cy/1920)>5e-7: bad(f"{oid} normalized {o['norm']} != {cx/1080:.6f},{cy/1920:.6f}")
    if not (x>=VP[0] and y>=VP[1] and x+w<=VP[0]+VP[2] and y+h<=VP[1]+VP[3]): bad(f"{oid} sprite out of scene viewport")
    if o["hit"]:
        hx,hy,hw,hh = o["hit"]
        if not (hx<=x and hy<=y and hx+hw>=x+w and hy+hh>=y+h): bad(f"{oid} hitbox does not contain sprite")
        if (hx+hw/2,hy+hh/2)!=(cx,cy): bad(f"{oid} hitbox not centred on sprite")
        if not (hx>=0 and hy>=VP[1] and hx+hw<=1080 and hy+hh<=VP[1]+VP[3]): bad(f"{oid} hitbox outside scene viewport")
        for dp_w in (360,):  # 1080 px canvas width == 360dp  => 1px = 1/3 dp (assumption, spec does not define px<->dp)
            if min(hw,hh)/3 < 48: bad(f"{oid} hitbox {min(hw,hh)/3:.0f}dp < 48dp at {dp_w}dp width")
ok("per-object center / normalized / containment / bounds checks done")
# pairwise overlap per case
def inter(a,b):
    ax,ay,aw,ah=a; bx,by,bw,bh=b
    w=min(ax+aw,bx+bw)-max(ax,bx); h=min(ay+ah,by+bh)-max(ay,by)
    return max(w,0)*max(h,0)
for case in ("C01","C02","C03"):
    ids=[i for i in reg if i.startswith(case) and reg[i]["hit"]]
    for a,b in itertools.combinations(ids,2):
        if inter(reg[a]["hit"],reg[b]["hit"])>0: bad(f"hitbox overlap {a}/{b}")
        # min gap
    gaps=[]
    for a,b in itertools.combinations(ids,2):
        A,B=reg[a]["hit"],reg[b]["hit"]
        dx=max(B[0]-(A[0]+A[2]),A[0]-(B[0]+B[2]),0); dy=max(B[1]-(A[1]+A[3]),A[1]-(B[1]+B[3]),0)
        gaps.append((max(dx,dy) if (dx==0 or dy==0) else (dx*dx+dy*dy)**.5,a,b))
    g=min(gaps); print(f"    {case}: smallest hitbox gap = {g[0]:.0f}px between {g[1]},{g[2]}")
ok("pairwise hitbox overlap check done (baseline)")
# ---- UI table normalized centers
uirow=re.compile(r"^\|\s*(UI_[A-Z0-9_]+)\s*\|\s*\[([^\]]+)\]\s*\|\s*([\d.]+),\s*([\d.]+)\s*\|")
for l in lines:
    m=uirow.match(l)
    if m:
        x,y,w,h=nums(m.group(2)); nx,ny=float(m.group(3)),float(m.group(4))
        if abs(nx-(x+w/2)/1080)>5e-7 or abs(ny-(y+h/2)/1920)>5e-7: bad(f"{m.group(1)} normalized mismatch")
        if min(w,h)/3<48: bad(f"{m.group(1)} < 48dp")
ok("UI table normalized centres checked")
# ---- Layout collisions in modal geometry (rects quoted in Part 3/4/8)
R=lambda *a:a
feedback=(96,1176,888,144)             # Part 8: wrong-feedback rect
slots=[(96+j*304,1104,280,192) for j in range(3)]  # Part 7: timeline slots
for j,s in enumerate(slots):
    ov=inter(feedback,s)
    if ov: bad(f"Wrong-feedback rect overlaps UI_TL_SLOT_{j}: {ov}px^2 = {100*ov/(s[2]*s[3]):.0f}% of slot (feedback z=230 > slot z=220)")
answers=[(96,600,888,168),(96,792,888,168),(96,984,888,168)]
for i,a in enumerate(answers):
    if inter(feedback,a): bad(f"feedback overlaps UI_ANSWER_{i}")
tokens=[(96,504+i*168,888,144) for i in range(3)]
for t in tokens:
    for s in slots:
        if inter(t,s): bad("token/slot overlap")
print("    token rows end y =", tokens[-1][1]+tokens[-1][3], "; slots y =", slots[0][1], "..", slots[0][1]+slots[0][3])
# ---- evidence card / answer capacity (assumption-based)
def cards(case):
    sect = txt[txt.index(f"# PART {dict(C01=5,C02=6,C03=7)[case]} "):]
    sect = sect[:sect.index("## State Machine")]
    return re.findall(r"^\|\s*(EV_C0\d_[A-Z_]+)\s*\|[^|]*\|[^|]*\|[^|]*\|[^|]*\|[^|]*\|\s*([^|]+?)\s*\|\s*(YES|NO)\s*\|", sect, re.M)
print("\nEvidence card text lengths (chars) — card slot is 144px = 48dp tall @360dp width; icon 48dp; text column ~230dp:")
for case in ("C01","C02","C03"):
    for eid,card,req in cards(case):
        est_lines=-(-len(card)//26)  # ~26 chars/line @16sp in ~230dp (assumption 0.55em avg glyph)
        print(f"    {eid:22s} {len(card):3d} chars  ~{est_lines} lines  need ~{est_lines*22+24}dp (title+copy) vs 48dp  req={req}")
# ---- answers: length heuristics
print("\nAnswer length heuristic ('longest = correct'):")
sect = txt
for qid,cor in (("C01_Q1","C01_Q1_A0"),("C01_Q2","C01_Q2_A1"),("C02_Q1","C02_Q1_A2"),("C03_Q1","C03_Q1_A0")):
    ans=re.findall(rf"^\|\s*({qid}_A\d)\s*\|\s*([^|]+?)\s*\|\s*(CORRECT|INCORRECT)\s*\|",txt,re.M)
    L={a:len(t) for a,t,_ in ans}; longest=max(L,key=L.get)
    print(f"    {qid}: lengths {L} longest={longest} correct={cor} -> {'LONGEST IS CORRECT' if longest==cor else 'ok'}")
    absw=[a for a,t,v in ans if v=="INCORRECT" and re.search(r"доказва|сигурност|доказано",t)]
    print(f"        wrong answers containing absolute words (доказва/със сигурност/доказано): {absw}")
# ---- cross references: object -> asset rows, evidence ids defined, hint & screen rows
asset_ids=set(re.findall(r"^\|\s*((?:A|I)_[A-Z0-9_]+)\s*\|",txt,re.M))
for oid in reg:
    if reg[oid]["hit"] is None: continue
    a="A_"+oid; d=a+"_DETAIL"
    if a not in asset_ids: bad(f"missing asset {a}")
    if d not in asset_ids: bad(f"missing asset {d}")
ev_def=set(re.findall(r"^\|\s*(EV_C0\d_[A-Z_]+)\s*\|[^|]*\|[^|]*\|\s*C0",txt,re.M))
ev_icons={e for e in re.findall(r"I_(EV_C0\d_[A-Z_]+)",txt)}
if ev_def!=ev_icons: bad(f"evidence/icon mismatch {ev_def^ev_icons}")
ok(f"asset/detail/icon cross-reference done ({len(ev_def)} evidence ids)")
# ---- time arithmetic claims
from datetime import datetime as D
f=lambda s:D.strptime(s,"%H:%M:%S")
assert (f("23:30:00")-f("22:48:00")).seconds==42*60; ok("C02 22:48 -> 23:30 = 42 min")
assert f("20:15:29")>=f("20:15:00") and f("20:15:31")<f("20:16:00"); ok("C03 photo window inside claim interval")
assert f("20:15:31")>f("20:10:00") and f("20:15:31")<f("20:35:00"); ok("C03 photo while R214 en route (no stop) per timetable")
print("\nTOTAL FAILS:",fail); sys.exit(1 if fail else 0)
