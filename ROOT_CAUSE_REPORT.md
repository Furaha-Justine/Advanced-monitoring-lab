# Observability Root Cause Report

## Summary

This report maps a user-visible symptom to the evidence found in metrics, traces, and logs, and then to the most likely root cause. The stack used here is:

- Application: Node.js/Express + MySQL
- Traces: OpenTelemetry → Jaeger
- Metrics: Prometheus → Grafana
- Logs: Winston JSON logs → Promtail → Loki → Grafana

The goal is to show how a single failure can be followed across the observability stack from symptom to trace to root cause.

---

## Scenario

### Symptom
Users report that the application becomes slow and occasionally returns errors when the `/users` endpoint is called during busy periods.

### What the user sees
- Pages load slowly
- `/users` sometimes returns HTTP 500
- Requests take longer than normal
- The app still appears healthy at the container level, but user experience degrades

---

## Step 1: Metric Signal

The first clue appears in Grafana.

### Prometheus/Grafana evidence
- `http_request_duration_seconds` shows a rising p95 latency on `/users`
- `http_errors_total` increases during the same period
- `http_requests_total` rises normally, so traffic is present and the app is not idle
- `http_active_connections` also climbs during the same window

### Interpretation
The app is not fully down. Instead, requests are taking too long and some are failing. This usually points to a downstream dependency, resource saturation, or a code path that is slow under load.

---

## Step 2: Trace Signal

The next step is to open Jaeger and inspect a slow `/users` request.

### Jaeger evidence
The trace shows:
- An incoming HTTP span for `GET /users`
- A database span underneath it for the MySQL query
- The DB span consumes most of the total trace duration
- The trace often ends with an error tag or a long gap before the response returns

### What the trace tells us
The application itself is responding, but it is spending most of the request time waiting on the database. That means the bottleneck is not the Express route handler alone. The trace narrows the problem to the MySQL call.

---

## Step 3: Log Signal

The final step is to search Loki using the same `trace_id` from Jaeger.

### Loki evidence
The JSON logs around the trace usually show:
- `Fetching users from database`
- `Users fetched successfully` or `Error fetching users`
- `duration_ms` values much higher than normal
- In failure cases, a MySQL error message or timeout-like behavior
- The same `trace_id` and `span_id` across the request lifecycle

### Interpretation
The logs confirm that the slowdown happens while the app is querying the database. The logs also show whether the request failed before the response was sent or completed slowly but successfully.

---

## Root Cause

### Most likely root cause
The `/users` endpoint is bottlenecked by the database query path.

### Why this is the root cause
- Metrics show latency and errors increasing together
- Traces show the majority of request time spent in the DB span
- Logs confirm the slow or failing request is tied to the same `trace_id`
- The application container is running, so the issue is not a crash

### Possible underlying reasons
- The `users` table is large and the query has no supporting index
- The database is under-provisioned
- Too many requests are hitting the endpoint at once
- Connections are being created and closed per request, adding overhead
- The query itself is simple, but the database is slow under load

---

## Recommended Fix

1. Add or verify indexes on columns used by `/users` queries
2. Reuse database connections through a pool instead of opening a fresh connection every time
3. Review MySQL performance under load
4. Add query timing and DB-level monitoring
5. Keep the existing trace/log correlation so future regressions are easy to diagnose

---

## Evidence Flow

### Symptom → Metric → Trace → Log → Root Cause

- **Symptom:** Users report slow `/users` responses and occasional 500s
- **Metric:** Grafana shows p95 latency and error rate rising
- **Trace:** Jaeger shows the request blocked in the MySQL span
- **Log:** Loki shows the same `trace_id` with a slow or failed DB call
- **Root Cause:** Database bottleneck in the `/users` request path

---

## Conclusion

The observability stack makes the issue easy to diagnose without guessing. Prometheus shows that something is wrong, Jaeger shows where the time is spent, and Loki confirms the exact request path and error context. In this case, the evidence points to the database as the main source of latency and failures for `/users`.

The key lesson is that the three signals work together:
- **Metrics** tell you that a problem exists
- **Traces** tell you where the time goes
- **Logs** tell you what happened in the request

That is the full symptom → trace → root cause workflow.
