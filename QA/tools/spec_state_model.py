#!/usr/bin/env python3
"""Executable model of the reducer rules in CASE_ZERO_Vertical_Slice_BG.md (Parts 2,5-7,10).
Explores ALL action sequences (BFS) per case and checks invariants. It tests the SPEC, not a build."""
import itertools, sys
from collections import deque
fails=0
def bad(m):
    global fails; fails+=1; print("FAIL:",m)

# ---------- C01 ----------
def c01_actions(s):
    ev,q,solved=s
    acts=[]
    for o in ("WINDOW","FLOOR","SHOES","CUP","CLOCK","MANAGER"): acts.append(("tap",o))
    acts+= [("sub","Q1",a) for a in range(3)]+[("sub","Q2",a) for a in range(3)]
    return acts
def c01_step(s,a):
    ev,q,solved=s; ev=set(ev); q=dict(q)
    if a[0]=="tap":
        o=a[1]
        if o=="WINDOW": ev.add("RAIN")
        elif o=="FLOOR": ev.add("DRY")
        elif o=="MANAGER" and q["Q1"]: ev.add("ADM")      # gate q.C01_Q1
    else:
        _,qid,ans=a
        if qid=="Q1" and {"RAIN","DRY"}<=ev and ans==0: q["Q1"]=True
        if qid=="Q2" and {"RAIN","DRY","ADM"}<=ev and q["Q1"] and ans==1: q["Q2"]=True
    solved = solved or (q["Q1"] and q["Q2"] and {"RAIN","DRY","ADM"}<=ev)
    return (frozenset(ev),tuple(sorted(q.items())),solved)
def explore(init,acts,step,inv,name,goal):
    seen={init}; dq=deque([init]); reach_goal=False
    while dq:
        s=dq.popleft()
        if goal(s): reach_goal=True
        inv(s)
        for a in acts(s):
            t=step(s,a)
            if t not in seen: seen.add(t); dq.append(t)
    print(f"{name}: {len(seen)} reachable states, goal reachable={reach_goal}")
    if not reach_goal: bad(f"{name} unsolvable")
    return seen
def c01_dict(s): return (s[0],dict(s[1]),s[2])
def c01_wrap_step(s,a):
    ev,q,sv=c01_dict(s); r=c01_step((ev,q,sv),a); return r
init=(frozenset(),(("Q1",False),("Q2",False)),False)
def c01_inv(s):
    ev,q,sv=s[0],dict(s[1]),s[2]
    if q["Q2"] and not q["Q1"]: bad("C01 Q2 true without Q1")
    if "ADM" in ev and not q["Q1"]: bad("C01 ADMISSION without Q1")
    if sv and not (q["Q1"] and q["Q2"]): bad("C01 solved without both Q")
seen=explore(init,c01_actions,c01_wrap_step,c01_inv,"C01",lambda s:s[2])
# premature-submit reachability: Q2 correct answer submitted while ADM missing must be rejected
s=c01_wrap_step(c01_wrap_step(c01_wrap_step(init,("tap","WINDOW")),("tap","FLOOR")),("sub","Q1",0))
s2=c01_wrap_step(s,("sub","Q2",1))
if dict(s2[1])["Q2"]: bad("C01 Q2 accepted before ADMISSION")
else: print("C01: Q2 before ADMISSION rejected (as spec)")
# spec gap: after Q1 true, can ADM be gained without further Q1? yes (tap MANAGER). FLOOR-before-WINDOW:
s=c01_wrap_step(init,("tap","FLOOR")); s=c01_wrap_step(s,("sub","Q1",0))
print("C01 FLOOR first then Q1 submit (guard must reject):", "REJECTED" if not dict(s[1])["Q1"] else "ACCEPTED")

# ---------- C02 ----------
# state: ev, power(0 empty/1 restored), charger_open_seen(bool: CHARGER inspected), link_ok, q1, solved
def c02_acts(s):
    a=[("tap","PHONE"),("tap","CHARGER"),("tap","RECORD"),("tap","WATCH"),("tap","CLOCK"),("cta",)]
    for k in itertools.combinations(("BAT","ID","NET","WATCH"),3): a.append(("connect",frozenset(k)))
    a+= [("q1",i) for i in range(3)]
    return a
def c02_step(s,a):
    ev,power,chseen,link,q1,solved=s; ev=set(ev)
    if a[0]=="tap":
        o=a[1]
        if o=="PHONE":
            ev.add("BAT")
            if power==1: ev.add("ID")
        elif o=="CHARGER": chseen=True
        elif o=="RECORD": ev.add("NET")
        elif o=="WATCH": ev.add("WATCH")
    elif a[0]=="cta":
        # CTA only exists inside CHARGER inspect panel (spec: requires route C02_INSPECT_CHARGER)
        if chseen: power=1
    elif a[0]=="connect":
        if {"ID","NET","WATCH"}<=ev and a[1]==frozenset({"ID","NET","WATCH"}): link=True
    elif a[0]=="q1":
        if {"ID","NET","WATCH"}<=ev and link and a[1]==2: q1=True
    solved = solved or (q1 and power==1 and link and {"ID","NET","WATCH"}<=ev)
    return (frozenset(ev),power,chseen,link,q1,solved)
def c02_inv(s):
    ev,power,chseen,link,q1,solved=s
    if "ID" in ev and power!=1: bad("C02 IDENTITY without RESTORED")
    if "ID" in ev and "BAT" not in ev: bad("C02 IDENTITY without BATTERY (spec: BATTERY added together)")
    if power==1 and not chseen: bad("C02 restored without charger inspected")
    if solved and not (link and q1): bad("C02 solved w/o link/q1")
seen=explore((frozenset(),0,False,False,False,False),c02_acts,c02_step,c02_inv,"C02",lambda s:s[5])
# Path A and Path B from the QA brief
def run(seq,st=(frozenset(),0,False,False,False,False)):
    for a in seq: st=c02_step(st,a)
    return st
A=run([("tap","PHONE"),("tap","CHARGER"),("cta",),("tap","PHONE")])
B=run([("tap","CHARGER"),("cta",),("tap","PHONE")])
print("C02 path A evidence:",sorted(A[0]),"| path B evidence:",sorted(B[0]))
if A[0]!=B[0]: bad("C02 paths A/B differ in evidence set")
# spec ambiguity: can the player solve WITHOUT ever tapping PHONE while EMPTY and WITHOUT BATTERY? (BATTERY optional)
if "BAT" in B[0]: print("C02: BATTERY always present when IDENTITY present (spec: added in same txn) -> consistent")
# CTA before inspecting CHARGER is impossible by spec (needs panel) -> modelled by chseen

# ---------- C03 ----------
import itertools as it
TL=("DEP","CLAIM","PHOTO")
def c03_acts(s):
    a=[("tap",o) for o in ("TICKET","CLOCK","TT","PHOTO","PLAT")]
    a+=[("pick",t) for t in TL]+[("slot",j) for j in range(3)]+[("submit_tl",)]
    for k in it.combinations(("TICKET","CLOCK","TT","PHOTO","PLAT"),3): a.append(("link",frozenset(k)))
    a+=[("q1",i) for i in range(3)]
    return a
def c03_step(s,a):
    ev,tl,sel,tok,link,q1,solved=s; ev=set(ev); tl=list(tl)
    ALL={"TICKET","CLOCK","TT","PHOTO","PLAT"}
    if a[0]=="tap": ev.add(a[1])
    elif a[0]=="pick": sel=a[1]
    elif a[0]=="slot":
        if sel is not None and ALL<=ev:
            if sel in tl: tl[tl.index(sel)]=None
            tl[a[1]]=sel; sel=None
    elif a[0]=="submit_tl":
        if ALL<=ev and None not in tl and len(set(tl))==3 and tl==list(TL): tok=True
    elif a[0]=="link":
        if ALL<=ev and tok and a[1]==frozenset({"PHOTO","CLOCK","PLAT"}): link=True
    elif a[0]=="q1":
        if ALL<=ev and tok and link and a[1]==0: q1=True
    solved=solved or (q1 and tok and link and ALL<=ev)
    return (frozenset(ev),tuple(tl),sel,tok,link,q1,solved)
def c03_inv(s):
    ev,tl,sel,tok,link,q1,solved=s
    vals=[t for t in tl if t]
    if len(vals)!=len(set(vals)): bad("C03 duplicate token in timeline")
    if link and not tok: bad("C03 link without timeline_ok")
seen=explore((frozenset(),(None,None,None),None,False,False,False,False),c03_acts,c03_step,c03_inv,"C03",lambda s:s[6])
# spec gap probe: displaced-token behaviour (occupied slot) keeps single copy
st=(frozenset({"TICKET","CLOCK","TT","PHOTO","PLAT"}),(None,None,None),None,False,False,False,False)
for a in [("pick","DEP"),("slot",0),("pick","CLAIM"),("slot",0)]: st=c03_step(st,a)
print("C03 displacement result:",st[1],"(old occupant must be unplaced, no duplicates)")
# spec gap: a token that is selected then slot tapped when selected==token already in the same slot
st=(st[0],("CLAIM",None,None),None,False,False,False,False)
for a in [("pick","CLAIM"),("slot",0)]: st=c03_step(st,a)
print("C03 re-place same token into own slot ->",st[1],"(spec silent; implementation-defined)")
print("\nMODEL FAILS:",fails); sys.exit(1 if fails else 0)
