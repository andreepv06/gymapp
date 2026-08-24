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
  `.github/workflows/deploy.yml` (build `flutter build web --release
  --base-href "/gymapp/"`, pubblicazione sul branch `gh-pages`).
- **Dominio applicativo già implementato**: esercizi, schede
  (workout), circuiti, sessioni con serie/ripetizioni/pesi, note
  esercizio, modalità di allenamento (con versionamento e
  soft-delete), storico, calendario, progressi/grafici, obiettivi
  (goals) con streak, sessioni sportive (corsa/ciclismo/ecc.),
  profilo utente con immagine.

La V1 **rimane invariata e pienamente funzionante** durante tutto lo
sviluppo descritto in questo documento.

## 2. Architettura target

\`\`\`
Flutter Web (UI + Provider)
        │
        │ HTTPS / REST (Repository + API Client — Fase 3)
        ▼
   NestJS API (Fase 1-2)
        │
        │ Prisma
        ▼
   PostgreSQL (Fase 1-2)
\`\`\`

Frontend, backend e database restano **componenti indipendenti**:
il frontend può in futuro essere spostato da GitHub Pages a Netlify
(o altro static hosting) senza toccare backend/database; il database
può essere spostato tra provider managed senza riscrivere Flutter,
grazie a Prisma come layer di astrazione.

## 3. Mappa di dipendenza attuale da Hive (V1)

\`\`\`
UI (screens/*)
  ↓
Provider (WorkoutProvider, ExerciseProvider, SessionProvider,
          GoalProvider, SportProvider, TrainingModeProvider,
          AuthProvider)
  ↓
Database layer locale (HiveDatabase, GoalDatabase, SportDatabase,
                        TrainingModeDatabase — box Hive per-utente)
  ↓
Hive (browser storage)
\`\`\`

Nessun livello "Repository"/"Service" astratto esiste oggi tra
Provider e i database Hive: i Provider chiamano direttamente i
metodi statici `*Database.instance.*`. Questo è il punto in cui, in
Fase 3, verrà inserito il nuovo livello:

\`\`\`
UI
  ↓
Provider (invariati nell'interfaccia pubblica, quando possibile)
  ↓
Repository (nuovo, Fase 3)
  ↓
API Client (nuovo, Fase 3) ──┬── HTTP → NestJS → PostgreSQL
                              └── fallback locale Hive (transizione)
\`\`\`

## 4. Schema dati (Fase 1)

Vedi `backend/prisma/schema.prisma`. Entità principali: `User`,
`UserProfile`, `RefreshToken`, `Exercise`, `ExerciseNote`,
`TrainingMode`, `TrainingModeSet`, `Workout`, `Circuit`,
`WorkoutExercise`, `Session`, `SessionSet`, `Goal`,
`GoalCompletion`, `SportSession`.

Differenze principali rispetto a una conversione meccanica di Hive:

- ogni riga ha una **foreign key esplicita verso l'utente
  proprietario** (`userId`), verificata sempre lato backend — mai
  dedotta da un ID che il client potrebbe manipolare;
- l'appartenenza di un `WorkoutExercise` a un circuito, codificata in
  V1 con un prefisso stringa dentro `notes`, diventa una vera FK
  (`circuitId`);
- `TrainingMode.sets` (lista embedded in Hive) diventa una tabella
  figlia `TrainingModeSet` con ordine esplicito;
- versionamento e soft-delete delle modalità di allenamento (già
  presenti in V1) sono preservati (`isDeleted`, `parentModeId`).

## 5. Autenticazione (predisposta in Fase 1, implementata in Fase 2)

- Password hashate con bcrypt lato server.
- JWT access token (breve durata) + refresh token (tabella
  `RefreshToken` dedicata, revocabile).
- Ruoli `USER` / `ADMIN` (enum `Role`), estendibile in futuro.
- Verifica email e recupero password: schema compatibile, flussi
  implementati in Fase 2 (richiede un provider SMTP esterno, quindi
  un intervento manuale dell'utente per la configurazione).

## 6. Sicurezza

- Nessun segreto nel repository: `.env` escluso da Git,
  `.env.example` versionato come template.
- CORS esplicito per origine (mai wildcard quando saranno coinvolte
  credenziali).
- Validazione input lato server (`class-validator`, Fase 2).
- Autorizzazione sempre verificata lato backend confrontando
  `userId` della risorsa con l'utente autenticato dal token — mai
  fidandosi di un ID passato dal client.

## 7. Migrazione da Hive

Hive **non viene rimosso in questa fase**. Strategia:

1. Fase 1-2: backend e database pronti, V1 invariata.
2. Fase 3: introduzione di un Repository layer in Flutter che può
   parlare con l'API; Hive può restare come cache/fallback locale
   durante la transizione.
3. Fase 4: procedura di migrazione dati (Hive → export JSON →
   validazione → import PostgreSQL) **solo dopo verifica esplicita**
   dell'utente; nessuna cancellazione dei dati Hive originali prima
   della verifica.

## 8. Hosting (indicazioni, dettagliate a inizio Fase 2)

- **Frontend**: resta su GitHub Pages finché non deciso
  diversamente; portabile su Netlify senza impatti su backend/DB.
- **Backend**: piattaforma da scegliere in Fase 2 (es. Render,
  Railway) — richiede azione manuale dell'utente (creazione account).
- **Database**: provider PostgreSQL managed da scegliere in Fase 2
  (vedi raccomandazione sotto) — richiede azione manuale dell'utente.

## 9. Ruoli e Admin Panel

Schema già predisposto (`Role.ADMIN`). L'interfaccia amministrativa
vera e propria (gestione utenti, gestione workout per conto di un
utente, audit log) è pianificata per la Macrofase 4, dopo che
autenticazione e API core saranno complete e testate.