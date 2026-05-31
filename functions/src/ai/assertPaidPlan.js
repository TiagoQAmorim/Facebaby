/** Plano pago (Plus): mensal, anual ou vitalício — campo `premiumLifetime` no Firestore. */
async function assertPaidPlan(db, uid, HttpsError) {
  const snap = await db.collection('users').doc(uid).get();
  const user = snap.data() || {};
  if (user.premiumLifetime !== true) {
    throw new HttpsError(
      'permission-denied',
      'Recurso disponível no plano pago (FaceBaby Plus).',
    );
  }
}

module.exports = { assertPaidPlan };
