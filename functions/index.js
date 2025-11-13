// functions/index.js (정식 버전 - 내일 마감 이벤트만)
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");

admin.initializeApp();

// ============================================================
// 🎯 1. 스케줄러 함수 (매일 오전 9시 실행)
// ============================================================
exports.checkEventDeadlines = onSchedule({
  schedule: "every day 09:00",
  timeZone: "Asia/Seoul"
}, async (event) => {
  console.log("⏰ ===== 이벤트 마감 알림 함수 실행 =====");
  await sendEventReminders();
  return null;
});

// ============================================================
// 🧪 2. HTTP 테스트 함수 (수동 실행용)
// ============================================================
exports.testEventReminders = onRequest(async (req, res) => {
  console.log("🧪 ===== 테스트 알림 함수 수동 실행 =====");

  try {
    await sendEventReminders();
    res.status(200).send("✅ 알림 발송 완료! Firebase Console 로그를 확인하세요.");
  } catch (error) {
    console.error("❌ 테스트 실패:", error);
    res.status(500).send("❌ 알림 발송 실패: " + error.message);
  }
});

// ============================================================
// 📨 핵심 알림 발송 로직 (정식 버전)
// ============================================================
async function sendEventReminders() {
  const db = admin.firestore();
  const messaging = admin.messaging();

  // 🔧 한국 시간대로 날짜 계산
  const now = new Date();

  // 한국 시간으로 변환 (UTC+9)
  const koreaOffset = 9 * 60 * 60 * 1000; // 9시간을 밀리초로
  const koreaTime = new Date(now.getTime() + koreaOffset);

  console.log("🕐 현재 UTC 시간:", now.toISOString());
  console.log("🕐 현재 한국 시간:", koreaTime.toISOString());

  // ✅ 정식: 내일 날짜만 검색
  const tomorrowStart = new Date(
    koreaTime.getFullYear(),
    koreaTime.getMonth(),
    koreaTime.getDate() + 1,  // 내일
    0, 0, 0
  );

  const tomorrowEnd = new Date(
    koreaTime.getFullYear(),
    koreaTime.getMonth(),
    koreaTime.getDate() + 1,  // 내일
    23, 59, 59
  );

  // UTC로 다시 변환
  const searchStartUTC = new Date(tomorrowStart.getTime() - koreaOffset);
  const searchEndUTC = new Date(tomorrowEnd.getTime() - koreaOffset);

  console.log("📅 검색 범위 (한국 시간 기준 내일):");
  console.log("  시작:", tomorrowStart.toISOString());
  console.log("  종료:", tomorrowEnd.toISOString());
  console.log("📅 검색 범위 (UTC 변환):");
  console.log("  시작:", searchStartUTC.toISOString());
  console.log("  종료:", searchEndUTC.toISOString());

  // 2. Firestore에서 내일 마감인 이벤트 조회
  const querySnapshot = await db.collection("events")
    .where("endDate", ">=", admin.firestore.Timestamp.fromDate(searchStartUTC))
    .where("endDate", "<=", admin.firestore.Timestamp.fromDate(searchEndUTC))
    .get();

  if (querySnapshot.empty) {
    console.log("📭 알림 보낼 이벤트 없음 (내일 마감 이벤트 없음)");
    return;
  }

  console.log(`📋 발견된 이벤트: ${querySnapshot.docs.length}개`);

  // 이벤트 목록 로깅
  querySnapshot.docs.forEach((doc, index) => {
    const event = doc.data();
    const endDateUTC = event.endDate.toDate();
    const endDateKorea = new Date(endDateUTC.getTime() + koreaOffset);
    console.log(`  ${index + 1}. ${event.title}`);
    console.log(`     마감(UTC): ${endDateUTC.toISOString()}`);
    console.log(`     마감(한국): ${endDateKorea.toISOString()}`);
  });

  // 3. 알림 메시지 생성
  const eventCount = querySnapshot.docs.length;
  const firstEventTitle = querySnapshot.docs[0].data().title;

  let notificationTitle;
  let notificationBody;

  if (eventCount === 1) {
    notificationTitle = `🔥 ${firstEventTitle} 마감 임박!`;
    notificationBody = `이벤트가 내일 마감됩니다. 잊지 말고 참여하세요!`;
  } else {
    notificationTitle = `🔥 ${eventCount}개의 이벤트 마감 임박!`;
    notificationBody = `${firstEventTitle} 외 ${eventCount - 1}개의 이벤트가 내일 마감됩니다.`;
  }

  console.log("📝 알림 내용:");
  console.log("  제목:", notificationTitle);
  console.log("  내용:", notificationBody);

  // 4. FCM 메시지 페이로드 구성
  const message = {
    notification: {
      title: notificationTitle,
      body: notificationBody,
    },
    data: {
      screen: "event_list",
      event_count: String(eventCount),
    },
    android: {
      notification: {
        channelId: "event_channel_id",
        sound: "default",
        priority: "high",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    topic: "event_reminders",
  };

  // 5. FCM 알림 발송
  try {
    const response = await messaging.send(message);
    console.log("✅ 알림 발송 성공!");
    console.log("  Message ID:", response);
    console.log(`  수신 대상: 'event_reminders' 토픽 구독자 전체`);
  } catch (error) {
    console.error("❌ 알림 발송 실패:", error);
    throw error;
  }
}