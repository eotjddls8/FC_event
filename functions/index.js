// functions/index.js (전체 내용)
const functions = require("firebase-functions");
const admin = require("firebase-admin");

// 🚨 V2 스케줄러를 위해 새로운 모듈을 require 해야 합니다.
const {onSchedule} = require("firebase-functions/v2/scheduler"); 

admin.initializeApp();

// 🎯 V2 문법으로 변경: onSchedule 함수 사용
exports.checkEventDeadlines = onSchedule({
    schedule: "every day 09:00",
    timeZone: "Asia/Seoul" // ⬅️ 한국 시간 기준
}, async (event) => {
    
    console.log("⏰ 이벤트 마감 알림 함수 실행...");

    const db = admin.firestore();
    const messaging = admin.messaging();

    // 1. 내일 날짜 계산
    const today = new Date();
    const tomorrowStart = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1, 0, 0, 0);
    const tomorrowEnd = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1, 23, 59, 59);

    // 2. Firestore에서 'endDate'가 내일인 모든 이벤트를 쿼리
    const querySnapshot = await db.collection("events")
      .where("endDate", ">=", admin.firestore.Timestamp.fromDate(tomorrowStart))
      .where("endDate", "<=", admin.firestore.Timestamp.fromDate(tomorrowEnd))
      .get();

    if (querySnapshot.empty) {
      console.log("알림 보낼 이벤트 없음.");
      return null;
    }

    // 3. 알림 보낼 메시지 생성
    const eventCount = querySnapshot.docs.length;
    const firstEventTitle = querySnapshot.docs[0].data().title;
    
    let notificationTitle = `🔥 ${firstEventTitle} 마감 임박!`;
    let notificationBody = `이벤트가 1일 남았습니다. 잊지 말고 참여하세요!`;
    
    if (eventCount > 1) {
        notificationTitle = `🔥 ${eventCount}개의 이벤트 마감 임박!`;
        notificationBody = `${firstEventTitle} 외 ${eventCount - 1}개의 이벤트가 내일 마감됩니다.`;
    }

    // 4. 알림 페이로드 구성
    const payload = {
      notification: {
        title: notificationTitle,
        body: notificationBody,
      },
      data: {
        "screen": "event_list", 
      },
    };

    // 5. 'event_reminders' 토픽으로 FCM 푸시 알림 발송
    try {
      await messaging.sendToTopic("event_reminders", payload);
      console.log(`✅ ${eventCount}개 이벤트 알림 발송 성공`);
    } catch (error) {
      console.error("❌ 알림 발송 실패:", error);
    }

    return null;
});