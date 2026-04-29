const admin = require("firebase-admin");

const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT;
if (!serviceAccountRaw) {
  throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret");
}

const serviceAccount = JSON.parse(serviceAccountRaw);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const messaging = admin.messaging();

async function run() {
  const gamesSnap = await db.collection("games").get();
  let totalGames = 0;
  let seededGames = 0;
  let dropsDetected = 0;
  let notificationsCreated = 0;
  let pushesSent = 0;

  for (const gameDoc of gamesSnap.docs) {
    totalGames += 1;
    const game = gameDoc.data() || {};
    const gameId = gameDoc.id;
    const title = String(game.titulo || "Juego");
    const currentPrice = parsePrice(game.precio);
    if (currentPrice == null) continue;

    const snapshotRef = db.collection("price_snapshots").doc(gameId);
    const snapshotDoc = await snapshotRef.get();
    const previousPrice = snapshotDoc.exists ? parsePrice(snapshotDoc.data().precio) : null;

    // First run: seed baseline only, do not notify.
    if (previousPrice == null) {
      seededGames += 1;
      await snapshotRef.set({
        precio: currentPrice,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      continue;
    }

    if (currentPrice < previousPrice) {
      dropsDetected += 1;
      notificationsCreated += await notifyUsersForPriceDrop({
        gameId,
        title,
        oldPrice: previousPrice,
        newPrice: currentPrice,
      });
    }

    await snapshotRef.set({
      precio: currentPrice,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  console.log(JSON.stringify({
    totalGames,
    seededGames,
    dropsDetected,
    notificationsCreated,
    pushesSent,
  }));

  async function notifyUsersForPriceDrop({gameId, title, oldPrice, newPrice}) {
    let created = 0;
    const usersSnap = await db.collection("users")
        .where("favorites", "array-contains", gameId)
        .get();
    if (usersSnap.empty) return created;

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const userData = userDoc.data() || {};
      const notificationId = `${uid}_${gameId}_${toPriceKey(newPrice)}`;

      await db.collection("notifications").doc(notificationId).set({
        uid,
        gameId,
        gameTitle: title,
        oldPrice,
        newPrice,
        leida: false,
        type: "price_drop",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      created += 1;

      const tokens = Array.isArray(userData.fcmTokens) ?
        userData.fcmTokens.filter((v) => typeof v === "string" && v.trim().length > 0) :
        [];
      if (tokens.length > 0) {
        const res = await messaging.sendEachForMulticast({
          tokens: tokens.slice(0, 500),
          notification: {
            title: "Bajada de precio",
            body: `${title} bajo de ${oldPrice.toFixed(2)} EUR a ${newPrice.toFixed(2)} EUR`,
          },
          data: {
            type: "price_drop",
            uid,
            gameId,
            oldPrice: oldPrice.toString(),
            newPrice: newPrice.toString(),
          },
        });
        pushesSent += res.successCount;
      }
    }

    return created;
  }
}

function parsePrice(value) {
  if (value == null) return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const raw = String(value).trim();
  if (!raw) return null;
  const normalized = raw.replace(",", ".").replace(/[^\d.]/g, "");
  if (!normalized) return null;
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
}

function toPriceKey(value) {
  return value.toFixed(2).replace(".", "_");
}

run().then(() => {
  console.log("price-alerts job finished");
  process.exit(0);
}).catch((error) => {
  console.error("price-alerts job failed", error);
  process.exit(1);
});
