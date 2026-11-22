# Catatan Implementasi AI Game

Dokumen ini memetakan materi kuliah ke implementasi game dan mencatat batas validasi. Script sudah dikelompokkan berdasarkan materi ke `scripts/week_02_agents/`, `scripts/week_03_pathfinding/`, `scripts/week_04_adversarial_search/`, `scripts/week_05_local_search/`, dan `scripts/week_06_csp/`. Script penghubung scene dan gameplay umum ada di `scripts/gameplay_integration/`; player tetap di `scripts/player/`.

## Cara membuktikan materi di dalam game

Saat game dibuka, menu utama menyediakan satu kartu untuk setiap materi dan tantangan. Pilih kartu untuk membaca pertanyaan, model, metode, dan bukti yang perlu diamati, lalu tekan **Mulai pembuktian terpilih**. Panel di arena menampilkan tujuan dan indikator langkah berikutnya; setelah bukti diperoleh, indikator berubah menjadi **BUKTI TERCATAT**. Gunakan **Kembali ke menu materi** untuk berpindah topik. **Mulai dungeon bebas** menjalankan tujuan permainan tanpa fokus satu materi.

| Menu | Aktivitas/bukti di arena |
|---|---|
| Tahap 1 · Pathfinding | Dekati NPC untuk memicu pencarian. Amati jalur/ekspansi dan statistik, atau tekan **Bandingkan Pathfinding** untuk membandingkan UCS, A* Manhattan, A* Euclidean, dan Greedy pada start/goal sama. |
| Tahap 2 · Minimax | Dekati NPC untuk memulai duel. Ubah metode, profil, dan kedalaman sebelum/selama duel; overlay duel menampilkan aksi, skor, node, waktu, dan perbandingan. |
| Tahap 3 · Local Search | Pilih Hill Climbing atau Simulated Annealing, tekan **Spawn NPC (Local Search)**, lalu amati fitness awal/akhir dan konfigurasi hasil. |
| Tahap 4 · CSP | Tekan **Spawn NPC (CSP)**. Status menampilkan apakah solver menemukan susunan valid beserta ringkasan assignment. |
| Tahap 5 · Logika | Dekati NPC; panel reasoning menampilkan fakta, rule, hasil inference, dan keputusan NPC. |
| Tahap 6 · Planning | Dekati NPC dengan ally dalam kondisi yang sesuai; panel reasoning menampilkan initial state, goal, plan forward/backward, heuristik, dan mutex. |
| Tantangan · Perilaku NPC | Amati siklus patroli, deteksi, chase, duel, dan kembali ke posisi awal. |
| Tantangan · Benchmark | Tekan **Benchmark Materi AI (Layar)**. Dialog yang dapat digulir memuat hasil Pathfinding serta benchmark Tahap 2–4. |

Kontrol materi yang tidak relevan disembunyikan per topik. Panel kontrol dapat digulir agar tetap muat pada layar pendek; dialog hasil benchmark juga dapat digulir.

## Materi agent dan PEAS (minggu 2)

NPC bergerak menuju player dengan tujuan mencapai target sambil mempertimbangkan rintangan/biaya tile, lalu mengambil keputusan duel. Perilaku ini terutama goal-based saat bergerak dan utility-based saat bertarung; state patrol/chase/return dan posisi home menyimpan konteks gerak, sehingga ada aspek model-based. NPC bukan learning agent: ia tidak melatih kebijakan dari pengalaman.

| PEAS | Penerapan di game |
|---|---|
| Performance | Mencapai player dengan biaya rute rendah; bertahan dan mengalahkan lawan; konfigurasi NPC menantang tetapi seimbang. |
| Environment | Arena 2D berbasis tile, player, NPC, rintangan, duri, dan state duel bergiliran. |
| Actuators | Bergerak antar-tile; menyerang, heavy attack, defend, atau memakai potion. |
| Sensors | Posisi pada grid, passability/biaya tile, posisi dan HP player, state NPC, serta HP/potion saat duel. |

Lingkungan pergerakan bersifat sebagian dinamis (player dan NPC bergerak), diskret pada perencanaan grid dengan interpolasi visual, dan diketahui oleh pencari jalur melalui grid yang disediakan. Duel bersifat sekuensial, dua pihak, dan deterministik pada Minimax/Alpha-Beta; Expectimax memodelkan peluang hit heavy attack. Ini menjelaskan kenapa materi agent diterapkan sebagai kerangka analisis, bukan sebagai kelas algoritma tambahan.

## Tahap 5: Logic & Representasi Pengetahuan

Materi ini diterapkan sebagai KB proposisional untuk koordinasi NPC. Fakta persepsi dimasukkan melalui TELL; inference engine forward-chaining menghasilkan fakta baru; agent memakai ASK untuk memilih keputusan. KB deklaratif dan inference engine terpisah di `scripts/week_07_logic/PropositionalKnowledgeBase.gd` dan `PropositionalInferenceEngine.gd`. Engine juga menyediakan model checking dengan truth table dan resolution refutation untuk query proposisional grounded. `LogicInferenceOverlay.gd` menampilkan fakta, rule yang terpicu, status entailment dari ketiga metode, langkah resolution, dan keputusan.

Aturan saat ini: ally yang sedang mengejar player bersama player yang dekat memicu `SUPPORT_ALLY`; ally dekat dengan player dekat memicu `COORDINATED_ASSAULT`; NPC Knight dengan ally dekat juga memicu koordinasi. Keputusan koordinasi memilih profil duel agresif; selain itu NPC memakai profil yang dipilih pengguna. Ini propositional logic yang di-ground ke situasi game. FOL dengan quantifier dan unification belum diterapkan; alternatif dan prompt kerja tersimpan di `PROMPT_PENERAPAN_LOGIC.md`.

## Tahap 6: Automated Planning (Week 8)

`AutomatedPlanner.gd` memodelkan fakta sebagai state faktored di bawah closed-world assumption. Aksi grounded menyimpan precondition, add effects, dan delete effects; hasil transisi mengikuti `(state - delete) ∪ add`. Planner menyediakan forward BFS dengan deduplikasi state, backward regression yang hanya memilih aksi relevant dan consistent, heuristic ignore-delete-lists, serta satu level planning graph dengan noop actions. Mutex dihitung dari interference, competing needs, dan inconsistent support. NPC mengubah fakta hasil KB menjadi initial state, merencanakan `support_ally` atau `coordinate_assault` lalu `engage_player`, dan menggunakan aksi plan sebagai keputusan taktis. Overlay menampilkan kedua arah plan, nilai heuristic, dan ringkasan mutex. Lihat [PROMPT_PENERAPAN_PLANNING.md](PROMPT_PENERAPAN_PLANNING.md).

| Komponen Week 8 | Status | Pemeriksaan |
|---|---|---|
| Factored state, initial/static facts, goal, closed-world | Diterapkan | Grounded predicate direpresentasikan sebagai fakta string; fakta yang tidak ada dianggap false. |
| Action schema, precondition, add/delete effects | Diterapkan | Transisi menghapus delete effects lalu menambahkan add effects. |
| Forward search dan pruning state yang pernah dilihat | Diterapkan | BFS memakai state key deterministik dan menghindari pengembangan ulang state. |
| Backward regression: relevant + consistent | Diterapkan | Aksi harus menambah fakta subgoal dan tidak boleh menghapus fakta goal; regresi berhenti saat subgoal tercakup initial state. |
| Ignore-delete-lists heuristic | Diterapkan | Efek delete diabaikan untuk mendapatkan estimasi level menuju goal. |
| Planning graph dan mutex | Diterapkan | Membuat no-op, action mutex, fact mutex via interference, competing needs, dan inconsistent support. Saat ini graph dibangun per level, belum melakukan Graphplan extraction penuh. |
| Integrasi KB Week 7 ke rencana NPC | Diterapkan | Fakta hasil inferensi menjadi state planner; plan taktis memilih dukungan ally atau koordinasi assault. |

Validasi planner dengan domain antar-paket dari materi menghasilkan plan forward dan backward yang sama: `drive_home_shop → pickup_shop → drive_shop_campus → drop_campus`. Heuristic ignore-delete bernilai 3; fakta posisi motor yang saling bertentangan ditandai mutex pada planning graph; goal yang tak terjangkau ditolak.

## Tahap 1: Pergerakan NPC dengan UCS dan A*

NPC controller ada di `scripts/week_02_agents/enemy.gd`. Metode ada di `scripts/week_03_pathfinding/UniformCostSearch.gd`, `AStarSearch.gd`, dan `GreedyBestFirstSearch.gd`; `SearchSupport.gd` menyediakan antrean prioritas dan hasil/rekonstruksi jalur. `pathfinding.gd` memilih algoritma dan mempertahankan API yang dipakai game.

- **Representasi peta:** tiap tile lantai passable adalah sebuah node; gerakan hanya ke atas, bawah, kiri, dan kanan.
- **Biaya langkah:** tile biasa berbiaya 1. Tile duri memiliki biaya yang lebih tinggi (default 10), sehingga algoritma mempertimbangkan rute yang menghindari duri bila rute alternatif lebih murah.
- **UCS:** prioritas node adalah biaya aktual dari awal, `g(n)`.
- **A\*:** prioritas node adalah `g(n) + h(n)`. Heuristik yang tersedia adalah Manhattan dan Euclidean. Keduanya admissible untuk gerakan ortogonal dengan biaya langkah minimum 1.
- **Greedy Best-First:** opsional dari pilihan algoritma; prioritas hanya `h(n)`, sehingga dapat cepat tetapi tidak menjamin rute termurah. UCS menggunakan `h(n)=0` sebagai kasus tanpa informasi heuristik.
- **Debug:** overlay menggambar urutan ekspansi dan jalur hasil. Panel menampilkan jumlah ekspansi, biaya jalur, dan waktu pencarian terakhir. Jika tidak ada jalur, node yang sempat diekspansi tetap ditampilkan.

## Tahap 2: Duel NPC dengan Minimax

Model state, aksi, transisi, utility, dan evaluasi bersama berada di `scripts/week_04_adversarial_search/MinimaxAI.gd`. Pencarian dipisah ke `MinimaxSearch.gd`, `AlphaBetaSearch.gd`, dan `ExpectimaxSearch.gd` dalam folder yang sama; `BattleManager.gd` menghubungkan AI dengan gameplay.

### State

State menyimpan HP saat ini dan maksimum, attack, defense, jumlah potion, serta status defend untuk player dan NPC. State disalin sebelum aksi agar pencarian tidak mengubah state permainan.

### Aksi dan transisi

Setiap giliran menyediakan `ATTACK`, `DEFEND`, `HEAVY_ATTACK`, dan `POTION` bila potion masih tersedia.

- Attack biasa memakai nilai attack karakter.
- Heavy attack memakai 1,5 kali attack (dibulatkan).
- Damage minimum adalah 1. Defense pasif mengurangi damage; status defend membagi dua damage setelah pengurangan defense.
- Potion memulihkan 25 HP hingga batas maksimum dan mengurangi jumlah potion satu.
- Giliran player dan NPC bergantian. NPC adalah pemain MAX dalam pencarian; player dimodelkan sebagai MIN.

### Terminal dan utility

Jika HP player habis, utility bernilai `+10000 + depth` untuk NPC. Jika HP NPC habis, utility bernilai `-10000 - depth`. Pada batas depth, fungsi evaluasi membandingkan selisih HP, potion, dan status defend. Bobot evaluasi berbeda untuk profil BALANCED, AGGRESSIVE, dan DEFENSIVE.

Alpha-Beta memakai fungsi evaluasi yang sama dengan minimax murni dan memangkas cabang saat `alpha >= beta`. Pembandingan runtime juga memakai varian early cutoff dengan batas 500 node. Depth berarti jumlah aksi/ply yang disimulasikan.

### Expectimax

Dalam mode Expectimax, heavy attack memiliki peluang hit 80% dan miss 20%. Hasil aktual di duel memakai undian dengan probabilitas yang sama, baik saat player maupun NPC memilih heavy attack. Pada mode Minimax dan Alpha-Beta, heavy attack deterministik agar transisi gameplay sesuai dengan model pencarian deterministik.

## Tahap 3: Konfigurasi NPC dengan Local Search

Fitness, combat power, optimizer, dan dua pencarian ada di `scripts/week_05_local_search/`: `NPCFitnessEvaluator.gd`, `LocalSearchOptimizer.gd`, `HillClimbingSearch.gd`, dan `SimulatedAnnealingSearch.gd`. Hill Climbing mengevaluasi seluruh tetangga satu-edit dan mengambil yang terbaik yang memperbaiki fitness (steepest ascent). Simulated Annealing mengambil tetangga acak dan dapat menerima langkah lebih buruk menurut temperatur.

Konfigurasi berisi jumlah NPC, tipe NPC, dan item. Fitness dihitung dari selisih combat power konfigurasi NPC terhadap player:

`combat_power = 0.6 × HP efektif + 2.0 × attack + 1.2 × defense`

HP efektif player dan NPC memperhitungkan potion yang tersedia. Fitness adalah `max(0, 100 - 100 × abs(power_NPC - power_player) / power_player)`. Simulated Annealing dapat menerima langkah yang lebih buruk berdasarkan temperatur; Hill Climbing hanya menerima tetangga yang fitness-nya meningkat.

NPC hasil optimasi dapat dibuat dari tombol **Spawn NPC (Local Search)**. Stats dan bonus item konfigurasi tersebut dipakai saat NPC memulai duel. Spawn dibatasi pada lantai passable, tidak di tile duri, setidaknya tiga tile dari player, dan tidak menumpuk di tile NPC lain.

## Tahap 4: Penempatan NPC dengan CSP

Formulasi domain, constraint, MRV/degree, LCV, Forward Checking, dan AC-3 ada di `scripts/week_06_csp/CSPSolver.gd`. Algoritma pencarian terpisah ada di `BacktrackingCSP.gd` dan `MinConflictsCSP.gd` dalam folder yang sama. Backtracking menjalankan AC-3 setelah setiap assignment (MAC) bila opsi AC-3 aktif.

- **Variabel:** slot lantai kandidat.
- **Domain:** tipe musuh dengan varian item, duri, atau kosong.
- **Unary constraints:** slot harus valid dan cukup jauh dari player; slot duri statis tidak boleh diisi musuh.
- **Binary constraints:** jarak minimum antarmusuh, duri, musuh-duri, serta jarak lebih besar untuk musuh elite.
- **Global constraints:** rentang jumlah musuh/duri dan batas total HP serta damage.
- **Pencarian lengkap:** backtracking dengan MRV, Degree, LCV, Forward Checking, dan AC-3.
- **Local search CSP:** Min-Conflicts dengan batas langkah.

Penempatan dapat dicoba dari **Spawn NPC (CSP)**. Tombol **Benchmark Materi AI (Layar)** menjalankan eksperimen pencarian dan menampilkan rincian di dialog dalam game. Slot khusus yang tidak passable, duplikat, dekat player, atau sudah menjadi duri akan ditolak.

## Kesesuaian dan batas materi

| Materi | Status | Catatan |
|---|---|---|
| Agent, PEAS, karakteristik environment | Diterapkan dan didokumentasikan | Perilaku NPC dijelaskan di atas; tidak ada learning agent. |
| UCS, Greedy, A*, heuristik dan metrik pencarian | Diterapkan | Overlay dan statistik tersedia; Greedy tidak optimal secara umum. |
| Minimax, Alpha-Beta, cutoff, utility/evaluation, urutan aksi | Diterapkan | Node count dan benchmark tersedia; hasil bergantung state dan depth. |
| Expectimax | Diterapkan sebagai pembanding opsional | Heavy attack memakai peluang hit 80%; hasil runtime stokastik. |
| Hill Climbing dan Simulated Annealing | Diterapkan | HC memilih best-improving neighbor; keduanya tetap dapat berhenti pada optimum lokal/batas iterasi. |
| CSP, backtracking, MRV, degree, LCV, FC, AC-3/MAC, Min-Conflicts | Diterapkan | Backtracking lengkap untuk finite domains; Min-Conflicts tidak menjamin solusi dan mengembalikan assignment terbaik saat batas langkah tercapai. |
| Genetic Algorithm dan learning agent | Tidak diterapkan | Materi kuliah umum, bukan kebutuhan tahap game yang ditentukan; tidak dipakai oleh fitur game saat ini. |

Perbaikan correctness pada audit ini: daftar variabel `unassigned` kini disalin per cabang backtracking agar rollback tidak mengubah parent; AC-3 dijalankan ulang sesudah assignment (MAC); Min-Conflicts tidak lagi mengubah assignment pemanggil ketika menghitung konflik dan mengembalikan kegagalan terdefinisi untuk domain kosong; Hill Climbing memakai tetangga terbaik, sesuai definisi steepest-ascent.

## Hasil eksperimen runtime

Jalankan **Benchmark Materi AI (Layar)** dari panel dalam game pada mesin yang sama. Baca metrik yang tampil di dialog; waktu dipengaruhi perangkat dan kondisi runtime.

| Eksperimen | Parameter | Hasil yang perlu dicatat |
|---|---|---|
| UCS vs Greedy vs A* | start/goal dan peta yang sama; catat heuristik | biaya jalur, jumlah ekspansi, waktu |
| Minimax vs Alpha-Beta | state, depth, profil, urutan aksi yang sama | aksi terpilih, skor, jumlah node, waktu |
| Early cutoff | batas 500 node | node yang dikunjungi, waktu, aksi |
| Profil evaluasi | BALANCED, AGGRESSIVE, DEFENSIVE | aksi dan skor per aksi |
| Simulated Annealing vs Hill Climbing | stats player dan konfigurasi awal yang sama bila membandingkan langsung | fitness awal/akhir, iterasi, waktu |
| Backtracking vs Min-Conflicts | slot dan constraints yang sama | sukses, node/langkah, konflik, waktu |

Benchmark tersedia di UI, tetapi angka runtime aktual bergantung mesin dan kondisi arena. Jalankan tombol benchmark untuk memperoleh angka yang sesuai dengan perangkat saat demonstrasi; tabel tetap perlu diisi dengan hasil run yang benar-benar diamati jika laporan tugas meminta angka eksperimen.
