// import admin from "npm:firebase-admin@11.11.0"

// // Initiate firebase
// if (!admin.apps.length) {
//   const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}');
//   admin.initializeApp({
//     credential: admin.credential.cert(serviceAccount)
//   });
// }

// Deno.serve(async (req) => {
//   try {
//     // Catch data from Supabase Webhook (after ordered)
//     const payload = await req.json()
//     const orderRecord = payload.record

//     if (!orderRecord) {
//       return new Response("Bukan data insert", { status: 200 });
//     }

//     const orderId = orderRecord.order_id
//     const total = orderRecord.total_price

//     // Prepare notification that will be sent to cashier
//     const message = {
//       topic: 'cashier',
//       notification: {
//         title: 'Pesanan Baru Masuk!',
//         body: 'Pesanan #${orderId} dengan total tagihan Rp ${total}.'
//       },
//       data: {
//         order_id: orderId.toString(),
//         type: 'NEW_ORDER'
//       }
//     };

//     // Send notification using Firebase Admin SDK
//     const response = await admin.messaging().send(message);

//     return new Response(JSON.stringify({ success: true, message_id: response }), {
//       headers: { "Content-Type": "application/json" },
//     })
//   } catch (error) {
//     console.error("FCM Error:", error);
//     return new Response(JSON.stringify({ error: error.message }), {
//       status: 400,
//       headers: { "Content-Type": "application/json" },
//     })
//   }
// })