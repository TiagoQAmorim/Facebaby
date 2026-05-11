# FaceBaby — Cloud Functions (Foto da Semana)

## Funções

| Export | Horário (America/Sao_Paulo) | Função |
|--------|------------------------------|--------|
| `scheduleWeeklyPhotoDraw` | Sexta 00:05 | Igual ao sorteio manual (`runWeeklyPhotoDraw`). **Se já existir `spotlight_current` com `status === 'active'`, mesmo `week_id` da semana corrente e `draw_at` preenchido**, não volta a sortear (para não apagar um sorteio antecipado com `forceWeeklyPhotoDraw`). |
| `forceWeeklyPhotoDraw` | HTTPS (manual) | **Força** o sorteio da semana corrente (`contestWeekKey(agora)`), escreve os mesmos documentos no Firestore. Protegido por secret — não usar na app. Qualquer cliente que abrir a app depois lê o mesmo `spotlight_current` (não há estado por utilizador). |
| `expireWeeklyPhoto` | Segunda 00:10 | Marca `spotlight_current` como `expired` para a app ocultar o cartão (o cliente também valida `display_until`). |

## Documentos esperados

### `public_memories/{docId}` (escrita pelo app)

Campos usados pelo sorteio (ver `WeeklyPhotoPublicSync` no Flutter):

- `submissionWeekId` — `YYYY-MM-DD` da segunda ISO em que a mãe marcou público (seg–qui).
- `photoUrl`, `badgeTitle`, `babyDisplayName`, `babySex` (`M` | `F`), `babyAgeLabel`, `publicDescription`, `createdAt`, `publicEnabledAt`, `userId`, `babyId`, `memoryId`.
- `userId` — obrigatório para contar no pool (dedupe por utilizador). `publicEnabledAt` — usado para escolher qual memória representa o utilizador quando há várias na mesma semana. `babySex` — copiado para `spotlight_current.winner_baby_sex` no sorteio (título Príncipe/Princesa na Home).

### `weekly_photo_contests/spotlight_current` (escrita pela função)

Campos lidos pela Home:

- `draw_at`, `display_until` (`Timestamp`)
- `winner_photo_url`, `winner_badge_title`, `winner_baby_display_name`, `winner_baby_sex` (`M` | `F` | omitido em memórias antigas), `winner_baby_age_label`, `winner_public_description`, `winner_memory_date`
- `status` — `active` | `expired` | `empty`

## Firestore — índices

Crie um índice composto se usar queries adicionais; para o sorteio atual basta `where('submissionWeekId','==', ...)`.

## Firestore — regras (esboço)

Coloque em `firestore.rules` no projeto Firebase (ajuste ao seu modelo de auth):

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /public_memories/{docId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.data.owner_uid == request.auth.uid;
    }

    match /weekly_photo_contests/{id} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}
```

O cliente grava `owner_uid` na primeira versão do sync — alinhe o campo em `FirestoreService.upsertPublicMemoryDoc` se usar outro nome.

## Sorteio antecipado (forçar esta semana)

1. Criar o secret (uma vez):  
   `firebase functions:secrets:set FORCE_WEEKLY_DRAW_SECRET`  
   (defina uma palavra-passe longa aleatória.)

2. Deploy: `firebase deploy --only functions` (o primeiro deploy com secret pode pedir permissões extra).

3. Chamar (substitua URL e token após o deploy):  
   `curl -H "Authorization: Bearer SEU_TOKEN" "https://southamerica-east1-<PROJECT_ID>.cloudfunctions.net/forceWeeklyPhotoDraw"`  
   Ou `GET ...?secret=SEU_TOKEN` (menos seguro em logs).

4. A partir daí, **sexta 00:05** continua a correr: na mesma semana **não** substitui um destaque já `active` com o mesmo `week_id` (o sorteio forçado mantém-se até segunda/`expireWeeklyPhoto` ou até à semana seguinte). Na **semana seguinte**, o cron volta a sortear normalmente.

## Deploy

Na raiz do projeto Firebase (onde está `firebase.json`):

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

Ajuste `region` em `index.js` se necessário. Para `forceWeeklyPhotoDraw`, configure o secret `FORCE_WEEKLY_DRAW_SECRET` antes ou durante o deploy.
