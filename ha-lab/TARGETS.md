# CloudNotes failover drill: recovery targets (declared BEFORE the failure)

| Item | Target |
|---|---|
| **Scope** | Only **app1** fails (process killed with SIGKILL). app2, proxy (HAProxy), the shared PostgreSQL store and the laptop keep running. Not tested: database, proxy, host or zone failure. |
| **RTO** | Stable note access within **10 seconds** of the failure command starting. *Recovered* = **5 consecutive successful reads served by app2** through the **same URL** `http://127.0.0.1:8080/api/notes`, with all baseline notes intact. |
| **RPO** | **0 seconds** of acknowledged-note loss. All 3 baseline notes (acknowledged with HTTP 201) must survive with identical ID, title, body and created_at. |
| **Method** | Timestamped requests (UTC + monotonic elapsed) every 0.5 s for **15 s** after the kill. Any later error **resets** the stable window. Exact before/after comparison against `baseline.json`. Then one new note write + read-back. |
| **Why these targets** | Users need note access back quickly (a few seconds of errors is acceptable, 10 s is the limit) and must never lose a note the app confirmed as saved. 0 s RPO is reasonable because storage is outside the failure scope. |
