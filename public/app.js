// public/app.js
async function go() {
  const location = document.getElementById("location").value || null;
  const language = document.getElementById("language").value || "ja-JP";
  const notes = document.getElementById("notes").value || null;

  const res = await fetch("/api/recommend", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ location, language, notes }),
  });

  const data = await res.json();
  const box = document.getElementById("result");
  box.style.display = "block";

  if (data.error) {
    box.innerHTML = `<strong>⚠️ Error:</strong> ${
      data.error
    }<br/><pre>${JSON.stringify(data.fallback, null, 2)}</pre>`;
    return;
  }

  const pretty = JSON.stringify(data, null, 2);
  const plan = data;

  // A friendlier render (fallback to JSON if missing fields)
  box.innerHTML = `
    <h2>Chef Plan</h2>
    <p><strong>Season:</strong> ${plan.season_context || "—"}</p>
    <p><strong>Style:</strong> ${plan.style || "—"}</p>
    <p><strong>Broth:</strong> ${plan.broth || "—"}</p>
    <p><strong>Tare:</strong> ${plan.tare || "—"}</p>
    <p><strong>Noodles:</strong> ${plan.noodles || "—"}</p>

    <p><strong>Toppings:</strong> ${(plan.toppings || []).join(", ")}</p>
    <p><strong>Garnish:</strong> ${(plan.garnish || []).join(", ")}</p>

    <h3>Method</h3>
    <ol>${(plan.method_steps || []).map((s) => `<li>${s}</li>`).join("")}</ol>

    <h3>Shopping List</h3>
    <ul>${(plan.shopping_list || []).map((i) => `<li>${i}</li>`).join("")}</ul>

    <p><em>${plan.serving_note || ""}</em></p>

    <details style="margin-top:12px;">
      <summary>Raw JSON</summary>
      <pre>${pretty}</pre>
    </details>
  `;
}

document.getElementById("go").addEventListener("click", go);
