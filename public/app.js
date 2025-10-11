// --- tiny helpers -----------------------------------------------------------
const $ = (id) => document.getElementById(id);
const esc = (v) =>
  String(v ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");

const listUL = (arr) =>
  Array.isArray(arr) && arr.length
    ? `<ul>${arr.map((x) => `<li>${esc(x)}</li>`).join("")}</ul>`
    : "<em>—</em>";

const listOL = (arr) =>
  Array.isArray(arr) && arr.length
    ? `<ol>${arr.map((x) => `<li>${esc(x)}</li>`).join("")}</ol>`
    : "<em>—</em>";

// Build one HTML block so we never query IDs that don't exist yet.
function renderPlan(container, data) {
  const plan = data.fallback ? data.fallback : data;
  const sc = plan.season_context || {};

  const raw = esc(JSON.stringify(plan, null, 2));
  const seasonIngr = Array.isArray(sc.suggested_ingredients)
    ? sc.suggested_ingredients.join(", ")
    : "";

  container.innerHTML = `
    <h2>🍜 Your Seasonal Ramen Plan</h2>

    <p><strong>Season:</strong> ${esc(sc.date) || "—"} — ${
    esc(sc.location) || "—"
  }
      ${seasonIngr ? ` (<em>ingredients:</em> ${esc(seasonIngr)})` : ""}
    </p>

    <div class="card">
      <p><strong>Style:</strong> ${esc(plan.style) || "—"}</p>
      <p><strong>Broth:</strong> ${esc(plan.broth) || "—"}</p>
      <p><strong>Tare:</strong> ${esc(plan.tare) || "—"}</p>
      <p><strong>Noodles:</strong> ${esc(plan.noodles) || "—"}</p>
    </div>

    <div class="card">
      <p><strong>Toppings:</strong></p>
      ${listUL(plan.toppings)}
      <p><strong>Garnish:</strong></p>
      ${listUL(plan.garnish)}
    </div>

    <div class="card">
      <p><strong>Method:</strong></p>
      ${listOL(plan.method_steps)}
    </div>

    <div class="card">
      <p><strong>Shopping List:</strong></p>
      ${listUL(plan.shopping_list)}
    </div>

    <p><strong>Serving Note:</strong> ${esc(plan.serving_note) || "—"}</p>

    ${
      data.error
        ? `<p style="color:#b00"><strong>⚠️ Model note:</strong> ${esc(
            data.error
          )}</p>`
        : ""
    }

    <details style="margin-top:12px;">
      <summary>Raw JSON</summary>
      <pre>${raw}</pre>
    </details>
  `;
}

// --- main interaction -------------------------------------------------------
function sanitizePayload(obj) {
  // drop empty strings so your backend sees "missing" instead of ""
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    const val = typeof v === "string" ? v.trim() : v;
    if (val !== "" && val != null) out[k] = val;
  }
  return out;
}

async function handleGenerate() {
  const btn = $("go");
  const box = $("result");
  const location = $("location")?.value ?? "";
  const language = $("language")?.value ?? "ja-JP";
  const notes = $("notes")?.value ?? "";

  btn.disabled = true;
  box.style.display = "block";
  box.textContent = "Generating…";

  try {
    const resp = await fetch("/api/recommend", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(sanitizePayload({ location, language, notes })),
    });

    // If server throws a non-200 for any reason:
    if (!resp.ok) {
      const text = await resp.text().catch(() => "");
      throw new Error(`HTTP ${resp.status} ${resp.statusText} ${text}`);
    }

    const data = await resp.json();
    renderPlan(box, data);
  } catch (err) {
    box.innerHTML = `<p style="color:#b00"><strong>⚠️ Error:</strong> ${esc(
      err?.message || err
    )}</p>`;
  } finally {
    btn.disabled = false;
  }
}

// --- wire up ---------------------------------------------------------------
document.addEventListener("DOMContentLoaded", () => {
  $("go")?.addEventListener("click", handleGenerate);

  // Optional: Enter-to-submit in the notes field
  $("notes")?.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      $("go")?.click();
    }
  });
});
