# Pathfinding Game (Tubes AI tahap - 1) — UCS & A* Search

Aplikasi simulasi game 2D interaktif (*grid-based*) yang mengimplementasikan algoritma **Uniform Cost Search (UCS)** dan **A* Search** untuk kalkulasi penelusuran jalur (*pathfinding*) NPC dalam mengejar Player.

Seluruh logika algoritma AI dan struktur data pencarian dijalankan **100% menggunakan bahasa Python** langsung di dalam browser melalui **Pyodide (WebAssembly)**, sehingga aplikasi ini dapat di-*host* di **GitHub Pages** atau dijalankan melalui **VS Code Live Server** tanpa membutuhkan server backend tambahan.

---

## Fitur Utama

* **Python-Powered AI Engine**: Seluruh kalkulasi algoritma kecerdasan buatan (*Priority Queue*, UCS, A*) dieksekusi secara native dalam Python via Pyodide WebAssembly.
* **Pilihan Algoritma & Heuristik**:
  * **Uniform Cost Search (UCS)**: Penelusuran jalur berbobot tanpa heuristik ($h(n) = 0$).
  * **A* Search (Manhattan)**: Penelusuran A* dengan fungsi heuristik jarak Manhattan.
  * **A* Search (Euclidean)**: Penelusuran A* dengan fungsi heuristik jarak Euclidean.
* **Visualisasi Wavefront Expansion**: Animasi ekspansi *node* (*frontier* / *closed list*) secara bertahap saat NPC melakukan kalkulasi rute terbaik.
* **Matriks Biaya Medan (Terrain Cost)**:
  * Rumput (`grass`): Biaya langkah = `1`
  * Pohon/Rintangan (`tree`): Rintangan tidak dapat dilewati (`#`)
  * Air (`water`): Biaya langkah berat = `7`
* **Panel Analisis & Perbandingan**: Menampilkan statistik *real-time* mengenai jumlah *expanded nodes*, total *path cost*, *path length*, waktu eksekusi Python (ms), dan perbandingan performa antar-algoritma.
* **Generasi Peta Prosedural**: Acak map otomatis untuk menguji performa AI pada berbagai bentuk rintangan.

---

## 📁 Struktur Proyek

```text
.
├── aset/
│   ├── grass.png       # Varian tekstur rumput 1
│   ├── grass2.png      # Varian tekstur rumput 2
│   ├── grass3.png      # Varian tekstur rumput 3
│   ├── npc.png         # Sprite NPC (Begal)
│   ├── player.png      # Sprite Player (Orang Cimahi)
│   ├── tree.png        # Rintangan pohon 1
│   ├── tree2.png       # Rintangan pohon 2
│   └── water.png       # Medan air (Biaya langkah = 7)
├── index.html          # Antarmuka utama & pemuat CDN Pyodide
├── pathfinding.py      # Core AI Engine (UCS, A*, Priority Queue)
├── script.js           # Controller, Canvas Rendering & JS-Python Bridge
├── style.css           # Styling UI & Layout
└── README.md           # Dokumentasi proyek
