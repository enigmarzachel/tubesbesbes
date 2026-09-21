// ================================================================
// script.js
// Powered by Python (Pyodide WebAssembly)
// ================================================================

let pyodideReady = false;
let pyodideInstance = null;

const canvas = document.getElementById("gameCanvas");
const ctx = canvas.getContext("2d");

const algorithmSelect = document.getElementById("algorithm");
const heuristicSelect = document.getElementById("heuristic");
const resetBtn = document.getElementById("resetBtn");
const randomBtn = document.getElementById("randomBtn");
const statsContent = document.getElementById("statsContent");
const historyContent = document.getElementById("historyContent");
const message = document.getElementById("message");
const compareResult = document.getElementById("compareResult");
const gameOverModal = document.getElementById("gameOverModal");
const restartBtn = document.getElementById("restartBtn");

const COLS = 20;
const ROWS = 15;
const CELL = 40;
const GRID_WIDTH = COLS * CELL;
const GRID_HEIGHT = ROWS * CELL;

let MAP = [];
const GRASS_KEYS = ["grass1", "grass2", "grass3"];
const TREE_KEYS = ["tree1", "tree2"];
const IMAGES = {};

function preloadImage(assetKey, src) {
  const img = new Image();
  img.src = src;
  IMAGES[assetKey] = img;
  img.addEventListener("load", () => { if (pyodideReady) draw(); });
}
preloadImage("grass1", "aset/grass.png");
preloadImage("grass2", "aset/grass2.png");
preloadImage("grass3", "aset/grass3.png");
preloadImage("tree1", "aset/tree.png");
preloadImage("tree2", "aset/tree2.png");
preloadImage("water", "aset/water.png");
preloadImage("npc", "aset/npc.png");
preloadImage("player", "aset/player.png");

// ----------------------------------------------------
// INISIALISASI PYTHON VIA WEBASSEMBLY (PYODIDE)
// ----------------------------------------------------
async function initPython() {
  try {
    message.className = "message";
    
    
    // Load Engine
    pyodideInstance = await loadPyodide();
    
    // Load Script Python kita
    const response = await fetch('pathfinding.py');
    const pythonCode = await response.text();
    await pyodideInstance.runPythonAsync(pythonCode);
    
    pyodideReady = true;
    message.className = "message status-success";
    
    statsContent.innerHTML = "Gerakkan Player untuk mulai.";
    
    // Setelah siap, mulai game
    heuristicSelect.disabled = false;
    randomizeMap();
  } catch (err) {
    console.error("Gagal memuat Python", err);
    message.className = "message status-error";
    message.textContent = "Gagal memuat Engine Python. Pastikan menggunakan Live Server.";
  }
}

// ----------------------------------------------------
// GAME LOGIC & RENDER
// ----------------------------------------------------
function pickRandom(list) {
  return list[Math.floor(Math.random() * list.length)];
}

let tileVariantMap = [];
function generateTileVariants() {
  const variants = [];
  for (let y = 0; y < ROWS; y++) {
    const row = [];
    for (let x = 0; x < COLS; x++) {
      const terrain = MAP[y][x];
      if (terrain === "#") row.push(pickRandom(TREE_KEYS));
      else if (terrain === "R") row.push("water");
      else row.push(pickRandom(GRASS_KEYS));
    }
    variants.push(row);
  }
  return variants;
}

let initialNpc = { x: 0, y: 0 };
let initialPlayer = { x: 0, y: 0 };
let npcCell = { ...initialNpc };
let playerCell = { ...initialPlayer };
let currentResult = null;
let isChasing = true;
let isGameOver = false;
let isProcessingMove = false;

let totalSearches = 0;
let totalExpanded = 0;
let totalSearchTime = 0;
let searchHistory = [];

let animContours = [];
let animRevealedKeys = new Set();
let animStepIndex = 0;
let animTimer = null;
let animPlaying = false;

function cellToPixel(cell) { return { x: cell.x * CELL, y: cell.y * CELL }; }
function sameCell(a, b) { return a.x === b.x && a.y === b.y; }

function drawSprite(assetKey, dx, dy, size) {
  const img = IMAGES[assetKey];
  if (img && img.complete && img.naturalWidth > 0) {
    ctx.drawImage(img, dx, dy, size, size);
    return true;
  }
  return false;
}

function drawGrid() {
  ctx.clearRect(0, 0, GRID_WIDTH, GRID_HEIGHT);
  ctx.imageSmoothingEnabled = false;

  for (let y = 0; y < ROWS; y++) {
    for (let x = 0; x < COLS; x++) {
      const terrain = MAP[y][x];
      const px = x * CELL;
      const py = y * CELL;
      const variantKey = tileVariantMap[y] ? tileVariantMap[y][x] : null;

      if (terrain === "#") {
        if (!drawSprite("grass1", px, py, CELL)) { ctx.fillStyle = "#d9f99d"; ctx.fillRect(px, py, CELL, CELL); }
        if (!drawSprite(variantKey, px, py, CELL)) { ctx.fillStyle = "#6b7280"; ctx.fillRect(px + 4, py + 4, CELL - 8, CELL - 8); }
      } else if (terrain === "R") {
        if (!drawSprite("water", px, py, CELL)) { ctx.fillStyle = "#60a5fa"; ctx.fillRect(px, py, CELL, CELL); }
      } else {
        if (!drawSprite(variantKey, px, py, CELL)) { ctx.fillStyle = "#d9f99d"; ctx.fillRect(px, py, CELL, CELL); }
      }

      ctx.strokeStyle = "rgba(107, 114, 128, 0.35)";
      ctx.strokeRect(px, py, CELL, CELL);

      if (terrain === "R") {
        ctx.fillStyle = "rgba(29, 78, 216, 0.9)";
        ctx.font = "bold 11px Arial";
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText("7", px + CELL - 9, py + CELL - 9);
      }
    }
  }
}

function drawDebug() {
  if (!currentResult) return;
  for (const cellKey of animRevealedKeys) {
    const [x, y] = cellKey.split(",").map(Number);
    ctx.fillStyle = "rgba(24, 132, 252, 0.68)";
    ctx.fillRect(x * CELL + 5, y * CELL + 5, CELL - 10, CELL - 10);
  }
  const lastContour = animContours[animStepIndex - 1];
  if (lastContour) {
    ctx.strokeStyle = "rgba(235, 37, 37, 0.9)";
    ctx.lineWidth = 2;
    for (const node of lastContour.nodes) {
      ctx.strokeRect(node.x * CELL + 3, node.y * CELL + 3, CELL - 6, CELL - 6);
    }
  }
  for (const cell of currentResult.frontierNodes) {
    ctx.fillStyle = "rgba(41, 30, 244, 0.79)";
    ctx.fillRect(cell.x * CELL + 9, cell.y * CELL + 9, CELL - 18, CELL - 18);
  }
  for (const cell of currentResult.path) {
    ctx.fillStyle = "rgba(255, 238, 0, 1)";
    ctx.fillRect(cell.x * CELL + 12, cell.y * CELL + 12, CELL - 24, CELL - 24);
  }
}

function drawEntities() {
  const spriteSize = CELL - 4;
  const inset = 2;
  const player = cellToPixel(playerCell);
  if (!drawSprite("player", player.x + inset, player.y + inset, spriteSize)) {
    ctx.fillStyle = "#8b5cf6"; ctx.beginPath(); ctx.arc(player.x + CELL / 2, player.y + CELL / 2, 13, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "white"; ctx.font = "bold 12px Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("P", player.x + CELL / 2, player.y + CELL / 2);
  }
  const npc = cellToPixel(npcCell);
  if (!drawSprite("npc", npc.x + inset, npc.y + inset, spriteSize)) {
    ctx.fillStyle = "#fb0202"; ctx.beginPath(); ctx.arc(npc.x + CELL / 2, npc.y + CELL / 2, 13, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = "white"; ctx.font = "bold 12px Arial"; ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("N", npc.x + CELL / 2, npc.y + CELL / 2);
  }

  if (isChasing) {
    ctx.strokeStyle = "rgba(0, 0, 0, 0.25)";
    ctx.setLineDash([5, 5]);
    ctx.beginPath();
    ctx.moveTo(npc.x + CELL / 2, npc.y + CELL / 2);
    ctx.lineTo(player.x + CELL / 2, player.y + CELL / 2);
    ctx.stroke();
    ctx.setLineDash([]);
  }
}

function draw() { drawGrid(); drawDebug(); drawEntities(); }

function updateStats(result) {
  if (!result) return;
  const avgEx = totalSearches > 0 ? (totalExpanded / totalSearches).toFixed(2) : "0";
  const avgTi = totalSearches > 0 ? (totalSearchTime / totalSearches).toFixed(3) : "0";
  statsContent.innerHTML = `
    <table>
      <tr><td>Algoritma</td><td>${algorithmSelect.value.toUpperCase()}</td></tr>
      <tr><td>Tujuan</td><td>(${playerCell.x}, ${playerCell.y})</td></tr>
      <tr><td>Expanded</td><td>${result.expandedNodes}</td></tr>
      <tr><td>Path cost</td><td>${result.pathCost ?? "No path"}</td></tr>
      <tr><td>Waktu cari (Python)</td><td>${result.searchTimeMs.toFixed(3)} ms</td></tr>
      <tr><td>Avg Waktu</td><td>${avgTi} ms</td></tr>
    </table>`;
}

function updateHistory() {
  const recent = searchHistory.slice(-12).reverse();
  historyContent.innerHTML = `
    <div class="history-box">
      <table>
        <tr><th>No</th><th>Aksi</th><th>Goal</th><th>Cost</th></tr>
        ${recent.map(item => `
          <tr><td>${item.number}</td><td>${item.source}</td><td>${item.goal}</td><td>${item.cost}</td></tr>
        `).join("")}
      </table>
    </div>`;
}

function buildContours(expansionOrder) {
  const contours = [];
  let currentLevel = null;
  let currentGroup = null;
  for (const node of expansionOrder) {
    const levelKey = Math.round(node.level * 1000) / 1000;
    if (currentGroup && levelKey === currentLevel) currentGroup.push(node);
    else {
      currentGroup = [node];
      currentLevel = levelKey;
      contours.push({ level: levelKey, nodes: currentGroup });
    }
  }
  return contours;
}

function stopAnimTimer() { if (animTimer) { clearInterval(animTimer); animTimer = null; } animPlaying = false; }
function prepareAnimation(result) {
  stopAnimTimer();
  animContours = result && result.expansionOrder ? buildContours(result.expansionOrder) : [];
  animRevealedKeys = new Set();
  animStepIndex = 0;
  playAnimation();
}
function stepAnimationOnce() {
  if (animStepIndex >= animContours.length) { stopAnimTimer(); return; }
  for (const node of animContours[animStepIndex].nodes) animRevealedKeys.add(`${node.x},${node.y}`);
  animStepIndex++; draw();
  if (animStepIndex >= animContours.length) stopAnimTimer();
}
function playAnimation() {
  if (!currentResult || animContours.length === 0) return;
  if (animStepIndex >= animContours.length) { animRevealedKeys = new Set(); animStepIndex = 0; }
  animPlaying = true;
  animTimer = setInterval(stepAnimationOnce, 320);
}

function showGameOverModal() { isGameOver = true; gameOverModal.classList.remove("hidden"); }
function hideGameOverModal() { isGameOver = false; gameOverModal.classList.add("hidden"); }

// ----------------------------------------------------
// KOMUNIKASI DENGAN PYTHON
// ----------------------------------------------------
function runPythonPathfinding(mapData, startData, goalData, algo, heur) {
  pyodideInstance.globals.set("js_map", JSON.stringify(mapData));
  pyodideInstance.globals.set("js_start", JSON.stringify(startData));
  pyodideInstance.globals.set("js_goal", JSON.stringify(goalData));
  pyodideInstance.globals.set("js_algo", algo);
  pyodideInstance.globals.set("js_heur", heur);
  
  const resultJson = pyodideInstance.runPython(`search_path_json(js_map, js_start, js_goal, js_algo, js_heur)`);
  return JSON.parse(resultJson);
}

async function compareAlgorithms() {
  if (!pyodideReady) return;
  const configs = [
    { name: "UCS", algorithm: "ucs", heuristic: "zero" },
    { name: "A* Manhattan", algorithm: "astar", heuristic: "manhattan" },
    { name: "A* Euclidean", algorithm: "astar", heuristic: "euclidean" }
  ];
  
  const results = configs.map(cfg => {
    const res = runPythonPathfinding(MAP, npcCell, playerCell, cfg.algorithm, cfg.heuristic);
    return { name: cfg.name, expandedNodes: res.expandedNodes, pathCost: res.pathCost, pathLength: res.pathLength };
  });

  compareResult.innerHTML = `
    <h3>Perbandingan Python (Posisi Saat Ini)</h3>
    <table>
      <tr><th>Algoritma</th><th>Expanded</th><th>Cost</th><th>Panjang</th></tr>
      ${results.map(item => `
        <tr><td>${item.name}</td><td>${item.expandedNodes}</td><td>${item.pathCost ?? "No path"}</td><td>${item.pathLength}</td></tr>
      `).join("")}
    </table>`;
}

async function calculateChasePath(showMessage = true, source = "Player") {
  if (!pyodideReady) return null;
  const algo = algorithmSelect.value;
  const heur = algo === "ucs" ? "zero" : heuristicSelect.value;

  const result = runPythonPathfinding(MAP, npcCell, playerCell, algo, heur);
  currentResult = result;
  
  totalSearches++;
  totalExpanded += result.expandedNodes;
  totalSearchTime += result.searchTimeMs;
  
  searchHistory.push({
    number: totalSearches, source: source, goal: `(${playerCell.x}, ${playerCell.y})`,
    expanded: result.expandedNodes, cost: result.pathCost ?? "-"
  });

  updateStats(result);
  updateHistory();
  prepareAnimation(result);
  compareAlgorithms();

  if (showMessage) {
    if (result.found) { message.className = "message status-success"; message.textContent = `Path ditemukan oleh Python.`; }
    else { message.className = "message status-error"; message.textContent = "No path found."; }
  }
  draw();
  return result;
}

async function moveNpcOneStep() {
  if (!isChasing || isGameOver || !currentResult || !currentResult.found) return;
  if (sameCell(npcCell, playerCell)) { showGameOverModal(); return; }

  const path = currentResult.path;
  const npcIndex = path.findIndex(cell => sameCell(cell, npcCell));
  if (npcIndex < 0 || npcIndex + 1 >= path.length) return;

  npcCell = { ...path[npcIndex + 1] };
  await calculateChasePath(false, "NPC");

  if (sameCell(npcCell, playerCell)) {
    message.className = "message status-error"; message.textContent = "Tertangkap!";
    setTimeout(showGameOverModal, 400);
  }
}

async function movePlayer(dx, dy) {
  if (isGameOver || sameCell(npcCell, playerCell) || !pyodideReady) return;
  const next = { x: playerCell.x + dx, y: playerCell.y + dy };
  if (next.x < 0 || next.x >= COLS || next.y < 0 || next.y >= ROWS || MAP[next.y][next.x] === "#") return;
  
  playerCell = next;
  await calculateChasePath(false, "Player");
  
  if (isChasing) {
    await moveNpcOneStep();
    if (!sameCell(npcCell, playerCell)) message.className = "message status-success";
  }
  draw();
}

async function randomizeMap() {
  if (!pyodideReady) return;
  hideGameOverModal();
  let mapValid = false;
  
  while (!mapValid) {
    MAP = [];
    for (let y = 0; y < ROWS; y++) {
      let row = "";
      for (let x = 0; x < COLS; x++) {
        const rand = Math.random();
        if (rand < 0.20) row += "#"; else if (rand < 0.35) row += "R"; else row += ".";
      }
      MAP.push(row);
    }
    tileVariantMap = generateTileVariants();

    function getEmptyCell() {
      let attempts = 0;
      while (attempts++ < 500) {
        const c = { x: Math.floor(Math.random() * COLS), y: Math.floor(Math.random() * ROWS) };
        if (MAP[c.y][c.x] !== "#") return c;
      }
      return { x: 0, y: 0 };
    }

    initialNpc = getEmptyCell();
    do { initialPlayer = getEmptyCell(); } while (sameCell(initialNpc, initialPlayer));

    const testRes = runPythonPathfinding(MAP, initialNpc, initialPlayer, "ucs", "zero");
    if (testRes.found && testRes.path.length > 1) mapValid = true;
  }
  await resetGame();
}

async function resetGame() {
  hideGameOverModal();
  isChasing = true; npcCell = { ...initialNpc }; playerCell = { ...initialPlayer };
  currentResult = null; totalSearches = 0; totalExpanded = 0; totalSearchTime = 0; searchHistory = [];
  stopAnimTimer(); animContours = []; animRevealedKeys = new Set(); animStepIndex = 0;
  await calculateChasePath(false, "Player");
}

window.addEventListener("keydown", async (event) => {
  const moves = { w: {x:0, y:-1}, s: {x:0, y:1}, a: {x:-1, y:0}, d: {x:1, y:0},
                  arrowup: {x:0, y:-1}, arrowdown: {x:0, y:1}, arrowleft: {x:-1, y:0}, arrowright: {x:1, y:0} };
  const k = event.key.toLowerCase();
  if (!moves[k]) return;
  event.preventDefault();
  if (isProcessingMove) return;
  isProcessingMove = true;
  await movePlayer(moves[k].x, moves[k].y);
  isProcessingMove = false;
});

algorithmSelect.addEventListener("change", async () => { heuristicSelect.disabled = algorithmSelect.value === "ucs"; await calculateChasePath(true, "Player"); });
heuristicSelect.addEventListener("change", async () => { if (algorithmSelect.value === "astar") await calculateChasePath(true, "Player"); });
resetBtn.addEventListener("click", resetGame);
randomBtn.addEventListener("click", randomizeMap);
restartBtn.addEventListener("click", randomizeMap);

// Panggil setup python
initPython();
