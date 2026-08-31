# MarkFit — Architettura

## 1. Stato attuale (V1)

- **Frontend**: Flutter Web.
- **Persistenza**: Hive (box locali per-utente, nel browser).
- **Autenticazione**: locale, gestita da `AuthProvider`
  (`lib/providers/auth_provider.dart`), account salvati in
  `SharedPreferences` come JSON. La password è attualmente salvata
  **in chiaro** in locale: è una debolezza nota della V1, non
  corretta in questa fase per non introdurre breaking change non
  richiesti. La nuova architettura backend **non replica** questo
  comportamento: le password lato server sono sempre hashate
  (bcrypt).
- **Hosting**: GitHub Pages, deploy automatico da `main` tramite
  `.github/workflows/deploy.yml`.
- **Dominio applicativo**: esercizi, schede (workout), circuiti,
  sessioni con serie/ripetizioni/pesi, note esercizio, modalità di
  allenamento (con versionamento e soft-delete), storico, calendario,
  progressi/grafici, obiettivi (goals) con streak, sessioni sportive
  (corsa/ciclismo/ecc.), profilo utente con immagine.

La V1 **rimane invariata e pienamente funzionante**. Nessuna modifica
a Hive, all'autenticazione locale o al comportamento applicativo è
mai stata effettuata durante questa evoluzione architetturale.

## 2. Architettura realizzata

```
Flutter Web (UI + Provider, V1 invariata)
        │
        │ HTTPS / REST (Repository + API Client, opt-in)
        ▼
   NestJS API  ──── https://gymapp-i09h.onrender.com/api
        │
        │ Prisma
        ▼
   PostgreSQL (Neon, managed)
```

Frontend, backend e database sono componenti indipendenti e
verificati in produzione:
- **Frontend**: GitHub Pages (`https://andreepv06.github.io/gymapp/`),
  portabile in futuro su altro static hosting senza impatti su
  backend/database.
- **Backend**: Render (piano free), deploy automatico da `main`,
  build command `npm install --include=dev && npx prisma generate &&
  npm run build`.
- **Database**: Neon PostgreSQL (serverless), schema applicato con
  `prisma migrate deploy`.

## 3. Stato di completamento per fase

### Fase 1 — Backend foundation
**Completata.** NestJS + Prisma + PostgreSQL, health check
(`GET /api/health`), Swagger (`/api/docs`), schema dati completo
mappato dai modelli Hive reali (non conversione meccanica: FK
esplicite per ownership, normalizzazione di circuiti e modalità di
allenamento).

### Fase 2 — Backend completo, autenticazione, API
**Completata.** JWT (access + refresh con rotazione), bcrypt,
`RolesGuard` con enum `USER`/`ADMIN`, CRUD completo con ownership
verificata lato server per: users, exercises (+ note), workouts
(+ circuits + workout-exercises), sessions (+ session-sets),
training-modes (con versionamento/soft-delete preservati), goals
(+ completions), sport-sessions, admin (lista utenti, dati sensibili
mai esposti).

### Fase 3 — Integrazione Flutter, Repository, sincronizzazione
**Completata e verificata con dati reali.** Layer `ApiClient` (con
refresh trasparente, gestione errori centralizzata, timeout adeguato
a hosting free-tier con cold start), `BackendAuthProvider` (separato
da `AuthProvider` V1), un `*SyncRepository` per dominio (exercises,
workouts+circuits, sessions+sets, training-modes, goals+completions,
sport-sessions), tutti **idempotenti** tramite mapping locale↔remoto
persistito (`SyncMappingStorage`) con fallback per nome/firma quando
l'utente cambia account V1 locale mantenendo lo stesso account
backend. Verificato con dati reali non banali: schede con esercizi
liberi e circuiti, sessioni con serie multiple (incluse incomplete),
obiettivi con completamenti storici.

Hive resta l'unica fonte di lettura per la sincronizzazione: **mai
una scrittura o cancellazione locale** in nessun repository di sync.

### Fase 4 — Admin Panel, deploy, migrazione
**Completata.**
- **Admin Panel**: schermata dedicata (`AdminUsersScreen`), accesso
  condizionato al ruolo `ADMIN` sia lato UI sia (soprattutto) lato
  backend (`RolesGuard`), verificata con un account admin dedicato
  che vede correttamente l'elenco utenti con ruoli distinti.
- **Deploy**: backend live su Render, database live su Neon,
  CORS configurato per l'origine esatta di produzione
  (`https://andreepv06.github.io`, senza path — il confronto CORS
  opera solo su schema+host, non sul path della pagina).
- **Multi-dispositivo**: verificato end-to-end — stesso account
  backend raggiunto da PC e da telefono via GitHub Pages, con
  sincronizzazione riuscita da entrambi.
- **Migrazione dati**: il meccanismo di sincronizzazione (Fase 3)
  costituisce la migrazione stessa — non un passaggio distruttivo
  separato. Ogni utente, quando lo desidera, sincronizza i propri
  dati Hive verso il backend dalla schermata "Sincronizzazione
  cloud" (azione opt-in, ripetibile, mai distruttiva verso Hive).
  Non esiste un evento di migrazione "una tantum" eseguito
  automaticamente: la V1 resta pienamente utilizzabile offline-first
  a tempo indeterminato, indipendentemente dal backend.

## 4. Sicurezza

- Nessun segreto nel repository: `.env` escluso da Git in ogni
  ambiente (locale, Render), `.env.example` versionato come
  template.
- CORS esplicito per origine esatta (mai wildcard).
- Password hashate con bcrypt lato server; mai esposte da nessun
  endpoint (incluso quello admin).
- Autorizzazione sempre verificata lato backend confrontando
  l'utente autenticato dal token con l'ownership della risorsa —
  mai fidandosi di un ID passato dal client.
- Promozione a ruolo `ADMIN` è un'operazione manuale diretta su
  database (nessun endpoint self-service di promozione, scelta
  deliberata per evitare un vettore di escalation privilegi).

## 5. Limiti noti e lavoro futuro (non bloccanti)

- **Sincronizzazione monodirezionale**: locale → backend. Non esiste
  ancora un percorso inverso (backend → Hive) né una vera
  risoluzione dei conflitti multi-dispositivo (l'ultimo che
  sincronizza "vince" semplicemente aggiungendo dati, senza merge).
- **Sport sessions**: non ancora testato con dati reali in un ciclo
  di sync (verificato solo strutturalmente).
- **Deprecazioni Flutter** (`withOpacity`→`withValues`, `Color.value`)
  presenti in tutta la UI esistente: `info`-level, non bloccanti,
  non introdotte da questo lavoro, non affrontate per restare
  focalizzati sulla ristrutturazione architetturale.
- **Piano free Render**: cold start dopo inattività (fino a ~50s),
  mitigato con timeout client a 60s ma non eliminato; da rivalutare
  con un piano a pagamento se l'uso diventa continuativo.
- **Rimozione di Hive**: intenzionalmente non pianificata in questa
  fase. Resta una decisione futura indipendente, da valutare solo
  dopo un periodo di utilizzo reale della sincronizzazione.