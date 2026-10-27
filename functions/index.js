const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.onUserDisconnectCleanup = functions.database.ref('/rooms/{roomId}/presence/{userId}')
    .onDelete(async (snapshot, context) => {
        const { roomId, userId } = context.params;
        const db = admin.firestore();
        const roomRef = db.collection('rooms').doc(roomId);

        console.log(`[Server] Start Cleanup for: ${userId}`);

        try {
            await db.runTransaction(async (transaction) => {
                const roomSnap = await transaction.get(roomRef);
                if (!roomSnap.exists) return;

                const data = roomSnap.data();
                const updates = {};

                // 1. حذف العضو من قائمة المتواجدين (Map update)
                updates[`users.${userId}`] = admin.firestore.FieldValue.delete();

                // 2. تحديث الكراسي (Array safe update)
                // بدلاً من التعديل بالنقطة، سنقوم بتعديل المصفوفة كاملة لضمان عدم سقوط البقية
                let seats = data.seats || [];
                let changed = false;

                // تحويلها لمصفوفة إذا كانت خريطة (للامان)
                if (!Array.isArray(seats)) {
                    const newSeats = Array(10).fill(null);
                    Object.keys(seats).forEach(k => {
                        const idx = parseInt(k);
                        if (idx >= 0 && idx < 10) newSeats[idx] = seats[k];
                    });
                    seats = newSeats;
                }

                // البحث عن الشخص وحذفه
                const finalSeats = seats.map(seat => {
                    if (seat && (seat.userId === userId || seat === userId)) {
                        changed = true;
                        return null;
                    }
                    return seat;
                });

                if (changed) {
                    updates['seats'] = finalSeats; // استبدال المصفوفة كاملة لضمان بقاء الآخرين
                    console.log(`[Server] User ${userId} removed from seat.`);
                }

                transaction.update(roomRef, updates);
            });
            console.log(`[Server] Cleanup success for ${userId}`);
        } catch (error) {
            console.error(`[Server] Cleanup failed:`, error);
        }
    });

// 3. تنظيف المنشورات منتهية الصلاحية تلقائياً كل ساعة وحذفها نهائياً مع تعليقاتها من قاعدة البيانات
exports.cleanupExpiredPostsScheduled = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date().toISOString();
    console.log(`[Scheduled Cleanup] Starting cleanup at ${now}`);

    try {
        const expiredSnapshot = await db.collection('posts')
            .where('expiresAt', '<', now)
            .get();

        if (expiredSnapshot.empty) {
            console.log('[Scheduled Cleanup] No expired posts found.');
            return null;
        }

        console.log(`[Scheduled Cleanup] Found ${expiredSnapshot.size} expired posts to clean up.`);

        // سنقوم بمسح المنشورات والتعليقات التابعة لها في دفعات (Batches)
        const batch = db.batch();
        
        for (const doc of expiredSnapshot.docs) {
            const postId = doc.id;
            console.log(`[Scheduled Cleanup] Preparing deletion for post ${postId}`);
            
            // جلب وحذف التعليقات التابعة للمنشور
            const commentsSnapshot = await db.collection('comments')
                .where('postId', '==', postId)
                .get();

            commentsSnapshot.docs.forEach(commentDoc => {
                batch.delete(commentDoc.ref);
            });

            // حذف مستند المنشور نفسه
            batch.delete(doc.ref);
        }

        await batch.commit();
        console.log(`[Scheduled Cleanup] Successfully deleted ${expiredSnapshot.size} expired posts and their associated comments.`);
    } catch (error) {
        console.error('[Scheduled Cleanup] Error during cleanup:', error);
    }
    return null;
});
