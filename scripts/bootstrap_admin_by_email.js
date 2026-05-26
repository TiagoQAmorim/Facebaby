/**
 * One-time: create admins_by_email/{email} (owner, active).
 * Run from repo root:
 *   node scripts/bootstrap_admin_by_email.js tamorim9000@gmail.com
 * Requires: gcloud auth application-default login  OR  GOOGLE_APPLICATION_CREDENTIALS
 */
const admin = require('../functions/node_modules/firebase-admin');

const email = (process.argv[2] || '').trim().toLowerCase();
if (!email || !email.includes('@')) {
  console.error('Usage: node scripts/bootstrap_admin_by_email.js user@example.com');
  process.exit(1);
}

admin.initializeApp({ projectId: 'facebaby-afc41' });
const db = admin.firestore();

async function main() {
  const legacy = await db.collection('admins').where('email', '==', email).limit(5).get();
  let role = 'owner';
  if (!legacy.empty) {
    const d = legacy.docs[0].data() || {};
    if (d.role === 'admin' || d.role === 'owner') role = d.role;
    console.log('Found legacy admins/', legacy.docs[0].id, 'role=', role);
  } else {
    console.log('No legacy admins doc — creating fresh allowlist entry.');
  }

  await db.collection('admins_by_email').doc(email).set(
    {
      email,
      role,
      active: true,
      bootstrappedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log('OK: admins_by_email/', email);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
