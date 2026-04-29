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
  const usersSnap = await db.collection("users").get();
  const favoriteMap = new Map();
  for (const userDoc of usersSnap.docs) {
    const userData = userDoc.data() || {};
    const favorites = Array.isArray(userData.favorites) ? userData.favorites : [];
    if (favorites.length === 0) continue;
    const tokens = Array.isArray(userData.fcmTokens) ?
      userData.fcmTokens.filter((v) => typeof v === "string" && v.trim().length > 0) :
      [];

    for (const gameId of favorites) {
      if (typeof gameId !== "string" || gameId.trim().length === 0) continue;
      if (!favoriteMap.has(gameId)) favoriteMap.set(gameId, []);
      favoriteMap.get(gameId).push({
        uid: userDoc.id,
        tokens,
      });
    }
  }

  const gameIds = Array.from(favoriteMap.keys());
  if (gameIds.length === 0) {
    console.log(JSON.stringify({
      totalGames: 0,
      seededGames: 0,
      dropsDetected: 0,
      notificationsCreated: 0,
      pushesSent: 0,
      message: "No hay juegos en favoritos para procesar",
    }));
    return;
  }

  let totalGames = 0;
  let seededGames = 0;
  let dropsDetected = 0;
  let notificationsCreated = 0;
  let pushesSent = 0;

  for (const gameIdChunk of chunkArray(gameIds, 200)) {
    const gameRefs = gameIdChunk.map((id) => db.collection("games").doc(id));
    const snapshotRefs = gameIdChunk.map((id) => db.collection("price_snapshots").doc(id));
    const [gameDocs, snapshotDocs] = await Promise.all([
      db.getAll(...gameRefs),
      db.getAll(...snapshotRefs),
    ]);

    for (let i = 0; i < gameIdChunk.length; i += 1) {
      const gameId = gameIdChunk[i];
      const userTargets = favoriteMap.get(gameId) || [];
      if (userTargets.length === 0) continue;

      const gameDoc = gameDocs[i];
      const snapshotDoc = snapshotDocs[i];
      if (!gameDoc.exists) continue;
      totalGames += 1;

      const game = gameDoc.data() || {};
      const title = String(game.titulo || "Juego");
      const currentPrice = parsePrice(game.precio);
      if (currentPrice == null) continue;

      const previousPrice = snapshotDoc.exists ? parsePrice(snapshotDoc.data().precio) : null;
      const snapshotRef = snapshotRefs[i];

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
        const result = await notifyUsersForPriceDrop({
          gameId,
          title,
          oldPrice: previousPrice,
          newPrice: currentPrice,
          userTargets,
        });
        notificationsCreated += result.created;
        pushesSent += result.pushesSent;
      }

      await snapshotRef.set({
        precio: currentPrice,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  }

  console.log(JSON.stringify({
    totalGames,
    seededGames,
    dropsDetected,
    notificationsCreated,
    pushesSent,
  }));

  async function notifyUsersForPriceDrop({
    gameId,
    title,
    oldPrice,
    newPrice,
    userTargets,
  }) {
    let created = 0;
    let sent = 0;

    for (const target of userTargets) {
      const uid = target.uid;
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

      const tokens = target.tokens;
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
        sent += res.successCount;
      }
    }

    return {created, pushesSent: sent};
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

function chunkArray(items, chunkSize) {
  const chunks = [];
  for (let i = 0; i < items.length; i += chunkSize) {
    chunks.push(items.slice(i, i + chunkSize));
  }
  return chunks;
}

run().then(() => {
  console.log("price-alerts job finished");
  process.exit(0);
}).catch((error) => {
  console.error("price-alerts job failed", error);
  process.exit(1);
});
