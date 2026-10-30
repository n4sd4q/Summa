# Summa — somme di Einstein veloci per Mathematica

`Summa` è un pacchetto Wolfram Language (funzione principale `Einsum`) per contrarre tensori con la sintassi di `numpy.einsum`. Non serve fare a mano trasposizioni e reshape. A differenza di `ResourceFunction["EinsteinSummation"]`, **un indice può comparire quante volte vuoi**: dentro lo stesso tensore (diagonali, tracce) e fra tensori diversi (iperarchi o indici di batch condivisi da 3, 4, … tensori).

```mathematica
Needs["Summa`"]

Einsum["ij,jk->ik", a, b]                 (* prodotto matriciale (BLAS) *)
Einsum["ijk,ijk,ijk->", a, b, c]          (* indici ripetuti 3 volte *)
Einsum["ai,bi,ci->abc", A, B, C]          (* ricostruzione CP: i condiviso da 3 tensori *)
Einsum["bij,bjk->bik", x, y]              (* matmul batched *)
Einsum["pa,aqb,brc,cs,pA,AqB,BrC,Cs->", A1, A2, A3, A4, A1, A2, A3, A4]  (* norma di un MPS *)
EinsumDiagram["ai,ibj,jck,kd->abcd"]      (* disegna la rete tensoriale *)
```

## Caratteristiche

- **Sintassi numpy completa**: `"ij,jk->ik"`, output implicito (`"ij,jk"` dà `"ik"` e `"ba"` traspone), ellissi `"...ij,...jk->...ik"` con broadcasting, assi di dimensione 1 che fanno broadcasting, operandi scalari (`",ij->ij"`), etichette Unicode (`"αβ,βγ->αγ"`) e freccia `→`.
- **Sintassi a liste** con etichette arbitrarie: `Einsum[{{"bond1","x"},{"x","bond2"}} -> {"bond2","bond1"}, a, b]`.
- **Indici ripetuti a piacere**: diagonali generalizzate (`"iij->j"`, `"iii->i"`), tracce, somme, iperarchi a 3 o più gambe.
- **Ordine di contrazione ottimizzato**: DP esatta sui sottoinsiemi (minimo numero di flop) fino a 8 tensori, poi greedy alla opt_einsum. In alternativa ordine sequenziale o un percorso scelto da te.
- **Kernel vettorializzati**. Ogni contrazione a coppie viene tradotta in:
  - `Dot` (BLAS/MKL), dopo un unico `Transpose` + `ArrayReshape` per operando e solo se serve davvero;
  - contrazioni batched (`C[b,i,k] = Σ_j L[b,i,j] R[b,j,k]`), con un modello di costo che sceglie fra un ciclo di `Dot` BLAS (matrici grandi) e il broadcasting vettoriale su array packed (batch grandi di matrici piccole);
  - prodotti di Hadamard o di broadcasting (prefisso/suffisso) senza trasposizioni.
- **Cache dei piani**: la seconda chiamata con le stesse dimensioni salta parsing e ottimizzazione. `EinsumFunction` precompila un einsum per forme fisse, utile nei loop.
- **Visualizzazione**: `EinsumDiagram` (rete tensoriale), `EinsumTree` (albero di contrazione con i costi) e `"Steps" -> True` (un fotogramma per contrazione, da animare).
- Funziona anche con array **simbolici**, **complessi**, interi esatti e `SparseArray` nei passi di tipo `Dot`. Ogni argomento che non è una lista (anche `Sqrt[2]` o `a + b`) è uno scalare.

## Installazione

Scegli una delle tre strade:

1. **Diretta**: `Get["/percorso/Summa/Kernel/Summa.wl"]`
2. **Paclet**: `PacletDirectoryLoad["/percorso/Summa"]; Needs["Summa`"]`
3. **Permanente**: copia la cartella `Summa` in `FileNameJoin[{$UserBaseDirectory, "Applications"}]`. Da quel momento basta `Needs["Summa`"]`.

Serve Mathematica 11.3 o successivo.

## Funzioni

| Funzione | Cosa fa |
|---|---|
| `Einsum[spec, t1, t2, …]` | calcola l'einsum. Opzioni: `"Path"` (`Automatic`, `"Optimal"`, `"Greedy"`, `"Sequential"`, `{{i,j},…}`), `"BatchMethod"` (`Automatic`, `"Dot"`, `"Vectorized"`), `"Cache"` (`True`) |
| `EinsumPath[spec, t1, …]` o `EinsumPath[spec, {dims1, …}]` | percorso scelto (formato lineare numpy, base 1), flop, flop naïf, speed-up, intermedio più grande, stringhe delle singole contrazioni |
| `EinsumFunction[spec, {dims1, …}]` | einsum precompilato: `ef[t1, t2]`. Proprietà: `ef["Path"]`, `ef["Flops"]`, `ef["Diagram"]`, `ef["Tree"]`, … Ha anche un riquadro di riepilogo con l'icona della rete |
| `EinsumDiagram[spec]`, `EinsumDiagram[spec, t1, …]` | disegno della rete tensoriale. Opzioni: `"ShowPath"`, `"Steps"`, `"Layout"` (`Automatic`, `"Circle"`, `"Line"` o coordinate), `"TensorNames"`, `"Highlight"`, `"ShowDimensions"` |
| `EinsumTree[spec, t1, …]` | albero di contrazione con indici, indici sommati e flop di ogni intermedio |
| `EinsumClearCache[]` | svuota la cache dei piani |

## Come vengono disegnati gli iperarchi

Ogni indice è un tensore COPY (una delta) con una gamba per ciascuna occorrenza, più una se l'indice compare nell'output:

- **2 gambe**: è un filo. Diventa un legame fra due tensori, una gamba aperta (indice di output) oppure un anello (traccia).
- **1 gamba**: l'indice viene sommato. La gamba finisce in un cerchietto, cioè una contrazione col vettore di uni.
- **3 o più gambe**: è un **iperarco**, disegnato come un pallino viola collegato a tutti i tensori che lo condividono.

Le gambe pendenti si sistemano negli spazi angolari liberi. Il layout automatico usa MDS classico sulle distanze del grafo, rifinito con stress majorization: le catene (MPS) vengono dritte, gli anelli circolari, le griglie a griglia. Lo spessore dei legami cresce con log(dimensione). I tensori con lo stesso nome hanno lo stesso colore, e passando il mouse su un elemento compare un tooltip con indici, dimensioni e ruolo.

`Examples/anteprima_diagrammi.png` mostra un'anteprima approssimata dei disegni, generata fuori da Mathematica.

`EinsumDiagram[..., "ShowPath" -> True]` mette su ogni legame il numero del passo in cui viene contratto. `ListAnimate[EinsumDiagram[spec, dims, "Steps" -> True]]` mostra la contrazione passo per passo: la coppia evidenziata è quella contratta subito dopo.

## Come funziona (e perché è veloce)

1. **Parsing e risoluzione**: le etichette diventano interi, l'ellissi si espande e le dimensioni vengono controllate, col broadcasting degli assi di dimensione 1.
2. **Preprocessing per operando**: le diagonali degli indici ripetuti si estraggono con `Transpose[t, {1,1,2,…}]`, cioè un Transpose con livelli ripetuti. Gli indici che non servono altrove vengono sommati subito con `Total`.
3. **Percorso**: per ogni sottoinsieme S di tensori, il risultato di S tiene solo gli indici che servono ancora fuori da S o nell'output. È questo che trasforma un indice condiviso da tre o più tensori in un **indice di batch** nelle contrazioni intermedie. Su questa base gira la DP O(3ⁿ) esatta per n ≤ 8, altrimenti la greedy.
4. **Lowering**: ogni passo L×R viene classificato in indici di batch, contratti e liberi. Si sceglie la combinazione di ordine degli operandi, ordine degli indici di batch e ordine degli indici contratti che minimizza i dati da trasporre, finale compreso. Poi si esegue il kernel migliore:
   - batch vuoto: `Dot` su matrici 2D;
   - batch con matrici grandi: `MapThread[Dot, …]`;
   - batch con matrici piccole: broadcasting vettoriale e `Total`;
   - nessun indice sommato con insiemi di indici annidati: prodotto con broadcasting.
5. **Esecuzione**: gli intermedi vengono liberati appena usati e il piano completo resta in cache.

Consigli per la massima velocità:

- usa array packed (`RandomReal`, `N[...]`, `Developer`ToPackedArray`);
- dentro i loop usa `EinsumFunction`, oppure chiama `Einsum` sempre con le stesse forme così la cache viene riusata;
- per reti con più di 8 tensori, se il tempo di pianificazione è trascurabile rispetto al calcolo, prova `"Path" -> "Optimal"` (fino a 14 tensori, oltre si usa la greedy con un avviso).

## Stato della verifica

Il pacchetto è stato sviluppato senza una licenza Mathematica. È stato verificato così:

- eseguendolo con Mathics3 (interprete open source del Wolfram Language) e confrontando i risultati con `numpy.einsum` su circa 2500 einsum casuali e scelti a mano, con tutti i percorsi e tutti i kernel: 0 errori;
- controllando che la DP trovi esattamente il costo minimo, confrontandola con una ricerca esaustiva;
- facendo rileggere il codice a parte per la semantica specifica di Mathematica (array packed, garbage collection dei simboli temporanei, opzioni).

Mathics però non ha gli array packed, BLAS né il front end. Le prime cose da fare con Mathematica sono quindi `TestReport` sulla suite e `Examples/Benchmarks.wl` per i tempi reali.

## Test

```mathematica
TestReport["/percorso/Summa/Tests/SummaTests.wlt"]
```

La suite contiene circa 700 test:

- 213 casi con risultati attesi calcolati da `numpy.einsum` in aritmetica intera esatta. Sono 63 casi scelti a mano, che coprono ogni kernel, più 150 casuali. I 63 casi scelti a mano vengono ripetuti con ogni strategia di percorso e con entrambi i metodi di batch;
- 40 reti per cui il costo del percorso `"Optimal"` deve coincidere con una ricerca esaustiva su tutti gli ordini di contrazione (e `"Greedy"` non può fare meglio);
- confronti in precisione macchina (reali e complessi) con una somma esplicita di riferimento;
- input simbolici e sparsi, sintassi alternative, messaggi di errore, `EinsumFunction` e diagrammi.

Per misurare i tempi sulla tua macchina c'è `Examples/Benchmarks.wl`, che confronta con equivalenti scritti a mano: `Dot`, `MapThread`, `TensorContract`, `Total`.

## File

```
Summa/
├── PacletInfo.m
├── Kernel/Summa.wl           ← il pacchetto
├── Kernel/init.m             ← loader per la cartella Applications
├── Tests/SummaTests.wlt      ← suite di test (TestReport)
├── Examples/SummaDemo.nb     ← notebook dimostrativo
├── Examples/Benchmarks.wl    ← benchmark
├── Examples/anteprima_diagrammi.png
└── README.md
```

## Limitazioni note

- Gli indici di output non possono ripetersi (`"i->ii"` non è ammesso, come in numpy).
- La DP ottimale è esponenziale: oltre 8 tensori il default è greedy, e `"Optimal"` è accettato fino a 14 tensori.
- `SparseArray` resta sparso solo nei passi di tipo `Dot`; negli altri kernel viene convertito in denso.
- Le costanti del modello di costo per i passi batched sono stime ragionevoli, non calibrate sulla tua macchina. Puoi forzare un kernel con `"BatchMethod"`.
