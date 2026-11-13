#!/usr/bin/env python3
"""CloudNotes HA failover drill (LU 5.8). Standard library only.

  python3 drill.py baseline   # confirm both replicas serve via the proxy, save 3 acknowledged notes
  python3 drill.py targets    # print the recovery targets (declare them BEFORE the failure)
  python3 drill.py failover   # kill app1, probe the SAME URL for 15 s, compare notes, write results
  python3 drill.py report     # print result.json and the target/result/verdict table
  python3 drill.py status     # check which replicas answer through the proxy (e.g. after restoring app1)
"""
import datetime as dt
import json
import os
import subprocess
import sys
import textwrap
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
URL = "http://127.0.0.1:8080"          # the one client entrypoint; never changed during the drill
NOTES_URL = URL + "/api/notes"
BASELINE = os.path.join(HERE, "baseline.json")
RESULT = os.path.join(HERE, "result.json")
LOG = os.path.join(HERE, "failover.log")
TARGETS = os.path.join(HERE, "TARGETS.md")

RTO_SECONDS = 10          # stable note access within 10 s of the failure command starting
RPO_SECONDS = 0           # zero acknowledged-note loss
STABLE_N = 5              # 5 consecutive successful app2 reads = recovered
OBSERVE_SECONDS = 15      # observation window
INTERVAL = 0.5            # pause between probes (plus request duration)
FAILED = "app1"
SURVIVOR = "app2"


def utc():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def request(method, url, data=None, timeout=2.0):
    """Return (status, served_by, body_json_or_None, error_or_None)."""
    body = None
    headers = {}
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(url, data=body, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            try:
                payload = json.loads(raw)
            except ValueError:
                payload = None
            return resp.status, resp.headers.get("X-Served-By", "?"), payload, None
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("X-Served-By", "?") if e.headers else "?", None, f"HTTP {e.code}"
    except Exception as e:  # connection refused, timeout, reset...
        return None, None, None, type(e).__name__ + ": " + str(getattr(e, "reason", e))


def compose(*args):
    return subprocess.run(["docker", "compose", *args], cwd=HERE, capture_output=True, text=True)


def container_states():
    out = compose("ps", "-a", "--format", "{{.Service}}\t{{.State}}\t{{.Status}}").stdout
    states = {}
    for line in out.strip().splitlines():
        parts = line.split("\t")
        if len(parts) == 3:
            states[parts[0]] = {"state": parts[1], "status": parts[2]}
    return states


def fmt_note(n):
    return {"id": n["id"], "title": n["title"], "body": n["body"], "created_at": n["created_at"]}


def compare_baseline(baseline_notes, current_list):
    by_id = {n["id"]: fmt_note(n) for n in (current_list or [])}
    lost, changed = [], []
    for b in baseline_notes:
        cur = by_id.get(b["id"])
        if cur is None:
            lost.append(b["id"])
        elif cur != b:
            changed.append(b["id"])
    return lost, changed


def line():
    print("-" * 96)


# ------------------------------------------------------------------ baseline
def cmd_baseline(force=False):
    if os.path.exists(BASELINE) and not force:
        sys.exit("baseline.json already exists. Keep it unchanged (or rerun with --force for a NEW run).")
    print(f"BASELINE   entrypoint {URL}   started {utc()}")
    line()
    print("1) Both replicas serve through the proxy (GET /health, round robin):")
    seen = set()
    for i in range(1, 9):
        status, who, payload, err = request("GET", URL + "/health")
        print(f"   {utc()}  #{i}  HTTP {status}  served_by={who}  {err or ''}")
        if status == 200:
            seen.add(who)
        if seen >= {FAILED, SURVIVOR} and i >= 4:
            break
        time.sleep(0.2)
    if not seen >= {FAILED, SURVIVOR}:
        sys.exit(f"Both identities were not seen through the proxy (saw {sorted(seen)}). Is the stack healthy?")
    print(f"   identities seen: {', '.join(sorted(seen))}  -> both replicas healthy and serving")
    line()
    print("2) Save 3 notes (acknowledged = HTTP 201 after the transaction commits):")
    run_id = dt.datetime.now(dt.timezone.utc).strftime("%H%M%S")
    notes = []
    for i in range(1, 4):
        title = f"HA baseline note {i} ({run_id})"
        status, who, payload, err = request("POST", NOTES_URL, {"title": title, "body": f"Saved before failover, run {run_id}, note {i}"})
        if status != 201:
            sys.exit(f"note {i} was not acknowledged: {status} {err}")
        s2, who2, full, err2 = request("GET", f"{NOTES_URL}/{payload['id']}")
        notes.append(fmt_note(full))
        print(f"   {utc()}  HTTP 201  served_by={who}  id={payload['id']}  created_at={full['created_at']}  \"{title}\"")
    states = container_states()
    with open(BASELINE, "w") as f:
        json.dump({"created_utc": utc(), "entrypoint": URL, "identities_seen": sorted(seen),
                   "containers": states, "notes": notes}, f, indent=2)
    line()
    print("3) Containers:")
    for svc in ("app1", "app2", "proxy", "db"):
        st = states.get(svc, {})
        print(f"   {svc:6} {st.get('state', '?'):8} {st.get('status', '')}")
    print(f"Baseline saved to baseline.json ({len(notes)} acknowledged notes). Do not edit it.")


# ------------------------------------------------------------------ targets
def cmd_targets():
    print(f"RECOVERY TARGETS   declared at {utc()}   (before any failure)")
    line()
    with open(TARGETS) as f:
        for row in f.read().splitlines():
            if row.startswith("| **"):
                cells = [c.strip().replace("**", "").replace("*", "").replace("`", "") for c in row.strip("|").split("|")]
                wrapped = textwrap.wrap(cells[1], width=76) or [""]
                print(f"{cells[0]:>17} : {wrapped[0]}")
                for more in wrapped[1:]:
                    print(f"{'':>17}   {more}")
    line()
    print(f"Script constants: RTO={RTO_SECONDS}s  RPO={RPO_SECONDS}s  stable={STABLE_N} consecutive {SURVIVOR} reads"
          f"  observe={OBSERVE_SECONDS}s  probe every {INTERVAL}s")
    print(f"Unchanged client URL: {NOTES_URL}")
    if os.path.exists(BASELINE):
        with open(BASELINE) as f:
            b = json.load(f)
        print(f"Baseline on file: {len(b['notes'])} notes, ids {[n['id'] for n in b['notes']]}, created {b['created_utc']}")
    if os.path.exists(RESULT):
        print("NOTE: result.json already exists from an earlier run.")
    else:
        print("No failover has been run yet (no result.json).")


# ------------------------------------------------------------------ failover
def cmd_failover():
    if not os.path.exists(BASELINE):
        sys.exit("Run `python3 drill.py baseline` first.")
    with open(BASELINE) as f:
        baseline = json.load(f)
    base_notes = baseline["notes"]
    log = open(LOG, "w")

    def out(msg):
        print(msg)
        log.write(msg + "\n")
        log.flush()

    out(f"FAILOVER DRILL   entrypoint {NOTES_URL} (unchanged)   scope: only {FAILED} fails")
    out("-" * 96)
    kill_utc = utc()
    t0 = time.monotonic()
    out(f"{kill_utc}  t=+0.000s  KILL: docker compose kill -s SIGKILL {FAILED}")
    k = compose("kill", "-s", "SIGKILL", FAILED)
    out(f"{utc()}  t=+{time.monotonic() - t0:.3f}s  kill command returned rc={k.returncode} ({FAILED} killed: "
        f"{'yes' if k.returncode == 0 else k.stderr.strip().splitlines()[-1:]})")
    out("-" * 96)
    out(f"{'UTC time':25} {'elapsed':>9}  {'result':10} {'served_by':9} {'baseline':9} stable")

    probes = []
    consecutive = 0
    recovered_at = None
    first_success = None
    errors = 0
    while time.monotonic() - t0 < OBSERVE_SECONDS:
        status, who, payload, err = request("GET", NOTES_URL)
        elapsed = time.monotonic() - t0
        ok = status == 200 and isinstance(payload, list)
        intact = False
        if ok:
            lost, changed = compare_baseline(base_notes, payload)
            intact = not lost and not changed
        good = ok and who == SURVIVOR and intact
        if good:
            consecutive += 1
            first_success = first_success if first_success is not None else elapsed
            if consecutive == STABLE_N and recovered_at is None:
                recovered_at = elapsed
        else:
            if not ok:
                errors += 1
            if recovered_at is not None:
                out(f"{'':25} {'':>9}  stable window RESET by a later failure")
            consecutive = 0
            recovered_at = None
        result = f"HTTP {status}" if status else "ERROR"
        mark = f"{min(consecutive, STABLE_N)}/{STABLE_N}"
        if good and consecutive == STABLE_N:
            mark += "  <- RECOVERED (stable)"
        elif good and consecutive > STABLE_N:
            mark += " stable"
        out(f"{utc():25} {'+' + format(elapsed, '.3f') + 's':>9}  {result:10} {str(who or '-'):9} "
            f"{('intact' if intact else ('-' if not ok else 'BROKEN')):9} {mark}"
            + (f"   ({err[:60]})" if err else ""))
        probes.append({"utc": utc(), "elapsed_s": round(elapsed, 3), "status": status, "served_by": who,
                       "baseline_intact": intact, "error": err})
        time.sleep(INTERVAL)

    out("-" * 96)
    # Exact RPO comparison after the window
    status, who, current, err = request("GET", NOTES_URL)
    lost, changed = compare_baseline(base_notes, current if isinstance(current, list) else [])
    # New write + read-back while app1 is still down
    title = f"HA after-failover note ({utc()[11:19]})"
    ws, wwho, wpayload, werr = request("POST", NOTES_URL, {"title": title, "body": "Written while app1 is down"})
    rs, rwho, rpayload, rerr = (None, None, None, "no id")
    if ws == 201:
        rs, rwho, rpayload, rerr = request("GET", f"{NOTES_URL}/{wpayload['id']}")
    write_read_ok = ws == 201 and rs == 200 and rpayload and rpayload.get("title") == title
    states = container_states()

    rto_met = recovered_at is not None and recovered_at <= RTO_SECONDS
    rpo_met = not lost and not changed
    result = {
        "run": {"kill_command_utc": kill_utc, "entrypoint": NOTES_URL, "observe_seconds": OBSERVE_SECONDS,
                "probe_interval_s": INTERVAL, "probes": len(probes), "errors_during_window": errors},
        "scope": f"Only {FAILED} process killed (SIGKILL). {SURVIVOR}, proxy, shared PostgreSQL and laptop kept running. "
                 "Database, proxy, host and zone failures NOT tested.",
        "targets": {"rto_seconds": RTO_SECONDS, "rpo_seconds": RPO_SECONDS,
                    "recovered_means": f"{STABLE_N} consecutive successful {SURVIVOR} reads via the same URL, baseline intact"},
        "observed": {
            "first_success_after_kill_s": None if first_success is None else round(first_success, 3),
            "stable_recovery_s": None if recovered_at is None else round(recovered_at, 3),
            "served_by_counts": {s: sum(1 for p in probes if p["served_by"] == s) for s in {p["served_by"] for p in probes}},
            "baseline_notes": len(base_notes),
            "lost_baseline_records": lost,
            "changed_baseline_records": changed,
            "new_note_write": {"status": ws, "served_by": wwho, "id": (wpayload or {}).get("id")},
            "new_note_read_back": {"status": rs, "served_by": rwho, "matches": bool(write_read_ok)},
            "containers_after": states,
        },
        "verdict": {"rto": "PASS" if rto_met else "FAIL", "rpo": "PASS" if rpo_met else "FAIL",
                    "new_write_read": "PASS" if write_read_ok else "FAIL",
                    "overall": "PASS" if (rto_met and rpo_met and write_read_ok) else "FAIL"},
    }
    with open(RESULT, "w") as f:
        json.dump(result, f, indent=2)
    log.close()
    print_table(result)
    print(f"\nSaved result.json and failover.log. {FAILED} was NOT restarted.")


def print_table(r):
    o, v, t = r["observed"], r["verdict"], r["targets"]
    rec = "not recovered" if o["stable_recovery_s"] is None else f"{o['stable_recovery_s']} s"
    rows = [
        ("Recovery (RTO)", f"<= {t['rto_seconds']} s", rec + f" (first success {o['first_success_after_kill_s']} s)", v["rto"]),
        ("Data loss (RPO)", f"{t['rpo_seconds']} s / 0 records",
         f"lost {len(o['lost_baseline_records'])}, changed {len(o['changed_baseline_records'])} of {o['baseline_notes']}", v["rpo"]),
        ("New note write/read", "201 then 200, same note",
         f"write {o['new_note_write']['status']} via {o['new_note_write']['served_by']}, read {o['new_note_read_back']['status']}",
         v["new_write_read"]),
        ("Scope", "app1 process only", "app2, proxy, DB, laptop up", "-"),
    ]
    print()
    print(f"{'CHECK':22} {'TARGET':26} {'OBSERVED':44} VERDICT")
    print("-" * 104)
    for row in rows:
        print(f"{row[0]:22} {row[1]:26} {row[2]:44} {row[3]}")
    print("-" * 104)
    print(f"OVERALL: {v['overall']}   (errors during window: {r['run']['errors_during_window']}, "
          f"served_by: {o['served_by_counts']})")


def cmd_report():
    if not os.path.exists(RESULT):
        sys.exit("No result.json yet. Run `python3 drill.py failover` first.")
    with open(RESULT) as f:
        r = json.load(f)
    print(json.dumps(r, indent=2))
    print_table(r)


def cmd_status():
    print(f"STATUS via {URL}   {utc()}")
    seen = set()
    for i in range(1, 9):
        status, who, payload, err = request("GET", URL + "/health")
        print(f"   {utc()}  #{i}  HTTP {status}  served_by={who}  {err or ''}")
        if status == 200:
            seen.add(who)
        time.sleep(0.2)
    print(f"   identities serving: {', '.join(sorted(seen)) or 'none'}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "baseline":
        cmd_baseline(force="--force" in sys.argv)
    elif cmd == "targets":
        cmd_targets()
    elif cmd == "failover":
        cmd_failover()
    elif cmd == "report":
        cmd_report()
    elif cmd == "status":
        cmd_status()
    else:
        sys.exit(__doc__)
