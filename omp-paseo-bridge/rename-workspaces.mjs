#!/usr/bin/env node
// Renames Paseo workspaces whose auto-derived name is "main" to the title of
// their first (oldest) agent — i.e. the imported omp session's message title.
// Drives the daemon WebSocket RPC directly (fetch_workspaces, fetch_agents,
// workspace.title.set) so it works with any paseo daemon — fork or official,
// Linux or macOS. Node >= 22 (built-in WebSocket).
//
// Usage: node rename-workspaces.mjs [--dry-run]
//        PASEO_WS_URL=ws://host:port node rename-workspaces.mjs

const WS_URL = process.env.PASEO_WS_URL || "ws://127.0.0.1:6767/ws";
const DRY = process.argv.includes("--dry-run");

const ws = new WebSocket(WS_URL);
let nextId = 1;
const pending = new Map();
let readyResolve;
const ready = new Promise((r) => { readyResolve = r; });

function req(message) {
  return new Promise((resolve, reject) => {
    const requestId = `rename-${nextId++}`;
    pending.set(requestId, { resolve, reject });
    ws.send(JSON.stringify({ type: "session", message: { requestId, ...message } }));
    setTimeout(() => {
      if (pending.has(requestId)) {
        pending.delete(requestId);
        reject(new Error(`timeout: ${message.type}`));
      }
    }, 15000);
  });
}

ws.onmessage = (ev) => {
  let frame;
  try { frame = JSON.parse(ev.data); } catch { return; }
  if (frame.type === "session" && frame.message && frame.message.type === "status") { readyResolve(); return; }
  const msg = frame.type === "session" ? frame.message : null;
  if (msg && msg.payload && msg.payload.requestId) {
    const p = pending.get(msg.payload.requestId);
    if (p) { pending.delete(msg.payload.requestId); p.resolve(msg); }
  }
};

ws.onopen = async () => {
  try {
    ws.send(JSON.stringify({
      type: "hello",
      clientId: "omp-bridge-rename",
      clientType: "cli",
      protocolVersion: 1,
      appVersion: "0.2.5",
      capabilities: {
        custom_mode_icons: true,
        reasoning_merge_enum: true,
        terminal_reflowable_snapshot: true,
        provider_subagents: true,
        project_updates: true,
      },
    }));
    await ready;

    const wsResp = await req({ type: "fetch_workspaces_request" });
    const agResp = await req({ type: "fetch_agents_request", filter: { includeArchived: true } });

    const workspaces = wsResp.payload.entries || [];
    const agents = (agResp.payload.entries || [])
      .map((e) => e.agent)
      .filter((a) => a.workspaceId && a.title);

    const byWs = new Map();
    for (const a of agents) {
      if (!byWs.has(a.workspaceId)) byWs.set(a.workspaceId, []);
      byWs.get(a.workspaceId).push(a);
    }

    const plan = [];
    for (const w of workspaces) {
      if ((w.name || "").trim() !== "main") continue;
      const list = (byWs.get(w.id) || [])
        .sort((a, b) => (a.createdAt || "").localeCompare(b.createdAt || ""));
      const first = list[0];
      if (!first) { console.log(`skip ${w.id} (${w.workspaceDirectory}): no titled agent`); continue; }
      const title = String(first.title).trim().slice(0, 90);
      if (!title) continue;
      plan.push({ workspaceId: w.id, cwd: w.workspaceDirectory, title });
    }

    console.log(`plan: ${plan.length} workspace(s) named "main" to rename`);
    for (const p of plan) console.log(`  ${p.workspaceId} -> "${p.title}" (${p.cwd})`);
    if (DRY) { ws.close(); return; }

    for (const p of plan) {
      const resp = await req({
        type: "workspace.title.set.request",
        workspaceId: p.workspaceId,
        title: p.title,
      });
      const acc = resp.payload && resp.payload.accepted;
      console.log(`${acc ? "ok" : "REJECTED"} ${p.workspaceId} -> "${p.title}"`);
      if (!acc) console.error(`  ${resp.payload.error || "unknown reason"}`);
    }
  } catch (e) {
    console.error("error:", e.message);
    process.exitCode = 1;
  }
  ws.close();
};

ws.onerror = (e) => {
  console.error("ws error:", e.message || `cannot connect to ${WS_URL}`);
  process.exitCode = 1;
};
