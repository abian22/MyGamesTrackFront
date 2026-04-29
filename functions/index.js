const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

exports.notifyPriceDrop = onDocumentUpdated("games/{gameId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const oldPrice = parsePrice(before.precio);
  const newPrice = parsePrice(after.precio);
  if (oldPrice == null || newPrice == null) return;
  if (newPrice >= oldPrice) return;

  const gameId = event.params.gameId;
  const gameTitle = (after.titulo || "Juego").toString();

  const usersSnap = await db
      .collection("users")
      .where("favorites", "array-contains", gameId)
      .get();

  if (usersSnap.empty) return;

  const now = admin.firestore.FieldValue.serverTimestamp();
  const promises = [];

  usersSnap.forEach((userDoc) => {
    const user = userDoc.data() || {};
    const uid = userDoc.id;
    const tokens = Array.isArray(user.fcmTokens) ? user.fcmTokens.filter(Boolean) : [];

    const notificationId = `${uid}_${gameId}_${safePriceKey(newPrice)}`;
    const notificationRef = db.collection("notifications").doc(notificationId);

    promises.push(
        notificationRef.set({
          uid,
          gameId,
          gameTitle,
          oldPrice,
          newPrice,
          leida: false,
          createdAt: now,
          type: "price_drop",
        }, {merge: true}),
    );

    if (tokens.length > 0) {
      promises.push(
          messaging.sendEachForMulticast({
            tokens: tokens.slice(0, 500),
            notification: {
              title: "Bajada de precio",
              body: `${gameTitle} bajó de ${oldPrice.toFixed(2)} EUR a ${newPrice.toFixed(2)} EUR`,
            },
            data: {
              type: "price_drop",
              uid,
              gameId,
              oldPrice: oldPrice.toString(),
              newPrice: newPrice.toString(),
            },
          }).catch(() => null),
      );
    }
  });

  await Promise.all(promises);
});

function parsePrice(value) {
  if (value == null) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const text = String(value).trim();
  if (!text) return null;
  const normalized = text.replace(",", ".").replace(/[^\d.]/g, "");
  if (!normalized) return null;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function safePriceKey(value) {
  return value.toFixed(2).replace(".", "_");
}
