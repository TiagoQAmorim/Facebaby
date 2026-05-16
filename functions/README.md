# FaceBaby — Cloud Functions (Foto da Semana)

## Funções

| Export | Horário (America/Sao_Paulo) | Função |
|--------|------------------------------|--------|
| `scheduleWeeklyPhotoDraw` | Domingo 23:58 | Sorteia entre `public_memories` com `submissionWeekId` igual à **segunda ISO da semana que termina nesse domingo** (calendário **America/Sao_Paulo** no código, não UTC do Node). Grava `spotlight_current` com `draw_at` = **segunda 00:00** seguinte (SP) e `display_until` = segunda seguinte. **Se já existir `spotlight_current` com `status === 'active'`, mesmo `week_id` e `draw_at` preenchido**, não volta a sortear. |
| `forceWeeklyPhotoDraw` | HTTPS (manual) | **Força** `runWeeklyPhotoDraw(new Date())` **sem** o “skip” do cron (útil se o domingo 23:58 falhou ou para um disparo único, ex. meio-dia via Cloud Scheduler). Secret obrigatório — não usar na app. |

> **Nota:** versões antigas expunham `expireWeeklyPhoto` (segunda 00:10). Esse agendamento foi removido: o fim da exibição é só pela janela `draw_at` / `display_until` no cliente; o sorteio seguinte substitui o documento `spotlight_current`. Após o deploy, pode apagar a função antiga no consola Firebase se ainda existir.

## Documentos esperados

### `public_memories/{docId}` (escrita pelo app)

Campos usados pelo sorteio (ver `WeeklyPhotoPublicSync` no Flutter):

- `submissionWeekId` — `YYYY-MM-DD` da segunda ISO da semana em que a mãe marcou a memória como pública (segunda a domingo, até 00:00 de segunda).
- `photoUrl`, `badgeTitle`, `babyDisplayName`, `babySex` (`M` | `F`), `babyAgeLabel`, `publicDescription`, `createdAt`, `publicEnabledAt`, `userId`, `babyId`, `memoryId`.
- `userId` — obrigatório para contar no pool (dedupe por utilizador). `publicEnabledAt` — usado para escolher qual memória representa o utilizador quando há várias na mesma semana. `babySex` — copiado para `spotlight_current.winner_baby_sex` no sorteio (título Príncipe/Princesa na Home).
- **Curtidas:** subcoleção `public_memories/{docId}/likes/{uid}` (escrita pelo app; leitura pública). A Home mostra a contagem em tempo real via `winner_public_memory_id` em `spotlight_current`.

### `weekly_photo_contests/spotlight_current` (escrita pela função)

Campos lidos pela Home:

- `draw_at`, `display_until` (`Timestamp`)
- `winner_photo_url`, `winner_badge_title`, `winner_baby_display_name`, `winner_baby_sex` (`M` | `F` | omitido em memórias antigas), `winner_baby_age_label`, `winner_public_description`, `winner_memory_date`, `winner_user_id` (Firebase Auth UID da mãe vencedora — usado pelo app para o modal de parabéns)
- `status` — `active` | `inactive` | `expired` (legado)

## Firestore — índices

Crie um índice composto se usar queries adicionais; para o sorteio atual basta `where('submissionWeekId','==', ...)`.

## Firestore — regras

O ficheiro na raiz do repositório é `firestore.rules` (referenciado em `firebase.json`). Deploy:

`firebase deploy --only firestore:rules`

Resumo: `public_memories` — leitura pública; create/update/delete só se `owner_uid` ou `userId` (existente / resultante) for o UID autenticado; `likes/{uid}` — leitura pública, create/delete só o próprio UID (um like por utilizador). `weekly_photo_contests` — leitura pública, escrita negada (só backend). `users/{uid}/**` — só o próprio utilizador.

## Sorteio antecipado (forçar)

1. Criar o secret (uma vez):  
   `firebase functions:secrets:set FORCE_WEEKLY_DRAW_SECRET`  
   (defina uma palavra-passe longa aleatória.)

2. Deploy: `firebase deploy --only functions` (o primeiro deploy com secret pode pedir permissões extra).

3. Chamar (substitui `SECRET` e o host após o deploy — 2ª gen. usa `*.run.app`):  
   `curl "https://southamerica-east1-<PROJECT>.cloudfunctions.net/forceWeeklyPhotoDraw?secret=SECRET"`  
   Ou header `x-force-weekly-draw-secret: SECRET` (evita secret em logs de URL se possível).

4. O cron de **domingo 23:58** não substitui um destaque já `active` com o mesmo `week_id` (útil após um sorteio forçado na mesma semana de pool).

## Deploy

Na raiz do projeto Firebase (onde está `firebase.json`):

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

Ajuste `region` em `index.js` se necessário. Para `forceWeeklyPhotoDraw`, configure o secret `FORCE_WEEKLY_DRAW_SECRET` antes ou durante o deploy.
