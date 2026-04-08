# Crewtalk

운송·물류 현장에서 **기사(드라이버)**, **관리자(매니저)**, **최고 관리자(슈퍼어드민)**가 함께 쓰는 **실시간 협업 앱**입니다. Flutter로 만들었고, 백엔드는 **Firebase**(프로젝트 ID: `crewtalk8`)를 사용합니다.

**기기 홈 화면·런처 표시 이름**은 **「크루톡」**입니다 (`ios/Runner/Info.plist`의 `CFBundleDisplayName`, `android/app/src/main/AndroidManifest.xml`의 `android:label`, 웹 `index.html`). Dart 패키지명·번들 내부 식별자는 `crewtalk`를 그대로 씁니다.

---

## 이 앱으로 할 수 있는 일

| 영역 | 설명 |
|------|------|
| **채팅** | 방(Room) 단위 실시간 메시지, 이미지, 공지, 긴급 알림 등 |
| **위치 추적(GPS)** | 포그라운드 서비스로 주행 궤적을 Firestore에 기록 (자동 종료 등 정책 있음) |
| **업무 보고** | 기사 측 보고(쿨다운 등 제한) |
| **긴급** | 긴급 메시지 시 FCM으로 매니저/슈퍼어드민에게 푸시 |
| **가상 방** | 방 번호 998·999는 Firestore에 없는 **앱 전용 UI** (아래 참고) |
| **카카오 내비 링크** | 방별로 설정된 카카오 공유 URL 등 (`/config/kakao_nav_links`) |
| **배차표 노출 예약** | **한국 날짜(KST)** 기준으로 **모든 채팅방** 헤더의 배차표1·2 버튼을 날짜별로 켜거나 끔 (`/config/timetable_visibility`, 방 목록 **＋** 메뉴) |

---

## 기술 스택

- **프레임워크**: Flutter (Dart SDK `^3.9.2`)
- **상태 관리**: [Riverpod](https://pub.dev/packages/flutter_riverpod) (`lib/providers/`)
- **라우팅**: [go_router](https://pub.dev/packages/go_router) (`lib/router/app_router.dart`)
- **로컬 DB**: [Drift](https://pub.dev/packages/drift) (SQLite) — 오프라인 캐시·읽음 상태·전송 실패 큐
- **Firebase**: Auth, Firestore, Cloud Functions, Storage, Cloud Messaging(FCM)
- **위치·백그라운드**: `geolocator`, `flutter_foreground_task`
- **기타**: 이미지 캐시, 로컬 알림, 오디오 알림(`audioplayers`) 등  
- **브랜딩(개발용)**: `flutter_launcher_icons`, `flutter_native_splash` — 마스터 이미지 `assets/icons/app_icon.png` (`pubspec.yaml` 참고)

---

## 지원 환경

- **Android / iOS**가 주 타깃이며, **웹**도 일부 동작합니다(예: GPS/FCM은 플랫폼에 따라 제한).
- 앱은 **세로 모드**로 고정됩니다 (`main.dart`).

---

## 사용자 역할과 권한(요약)

역할 문자열은 코드에서 정규화되며, 대표적인 권한은 다음과 같습니다.

| 역할 | 특징(요약) |
|------|------------|
| **driver** | 채팅, GPS, 보고 |
| **manager** | 위 + 가상 방(998/999), 방송 공지 등 |
| **superadmin** | 위 + 방/회사 CRUD, 설정 쓰기, 조정(모더레이션) 등 |

회사명 **「관리자」**는 Firestore 규칙상 특별 취급되는 관리 회사로 다룹니다.

자세한 플래그(`isStaffElevated`, `canBroadcast` 등)는 `UserModel`과 보안 규칙을 함께 보는 것이 좋습니다.

**배차표 노출 예약**은 Firestore `config` 쓰기 권한과 맞추기 위해 **`canWriteRoomMetaOnFirestore`**(슈퍼어드민 또는 소속명 **「관리자」**)인 계정만 앱에서 편집할 수 있습니다. 매니저만으로는 편집 불가입니다.

---

## 전역 배차표 노출(`config/timetable_visibility`)

- **목적**: 각 방에 배차표 이미지가 있어도, **특정 한국 날짜**에만 헤더의 **배차표1 / 배차표2** 버튼을 숨기거나 보이게 합니다. **방마다 설정하지 않고** 문서 한 곳에서 전 방에 공통 적용됩니다.
- **날짜 키**: `YYYY-MM-DD` 형태이며, 앱에서는 **KST(UTC+9) 달력 날짜**를 사용합니다 (`lib/utils/kst_date.dart`).
- **문서 형식(예)**:
  - `byDate`: 맵. 키 = 날짜 문자열, 값 = `{ "slot1": bool, "slot2": bool }` — 해당 날짜에 버튼 노출 여부.
  - `updatedAt`: 서버 타임스탬프(선택).
- **규칙이 없는 날짜**: 해당 날짜에 `byDate` 항목이 없으면 **기존과 같이**, 방에 이미지가 있으면 버튼을 표시합니다.
- **앱 연동**: `FirestoreRoomSync`가 문서를 구독해 `globalTimetableVisibilityProvider`를 갱신하고, `chat_screen` 헤더에서 오늘(KST) 규칙과 `RoomModel`의 배차표 이미지 유무를 함께 봅니다. Firestore 쓰기/구독은 `ChatFirestoreRepository`를 참고하세요.
- **보안 규칙**: 기존 `match /config/{docId}` 규칙에 포함됩니다(`kakao_nav_links` 제외 문서는 `isElevatedAdmin()` 쓰기). 별도 규칙 파일 항목 추가는 필요 없습니다.

---

## 인증 방식

- **이메일/비밀번호** 기반 Firebase Auth.
- 이메일은 전화번호 등에서 만든 **합성 이메일** 형태(`{숫자}@crew.co.kr` 등, `PhoneAuthUtils`)를 사용합니다.
- 회사 비밀번호 검증은 **Cloud Function** `verifyCompanyPassword`에서 수행되며, 실패 횟수에 **레이트 리밋**이 있습니다.

---

## Firestore 데이터 모델(개략)

개발 시 자주 보는 경로 예시입니다.

| 경로 | 용도 |
|------|------|
| `/config/rooms` | 방 목록 |
| `/config/kakao_nav_links` | 방별 카카오 내비 링크 |
| `/config/timetable_visibility` | 전역 배차표1·2 **헤더 버튼** 노출 예약(날짜별). 방 메타의 이미지 유무와 함께 적용 |
| `/rooms/{roomId}/messages` | 채팅 메시지 |
| `/users/{uid}` | 사용자 프로필, `fcmTokens[]`, 채팅 푸시용 **`messageNotifSoundEnabled`** / **`messageNotifVibrateEnabled`**(앱 설정과 동기화, 기본 `true`로 간주) 등 |
| `/tracks/{trackId}/points/{pointId}` | GPS 궤적 점 |
| `/company_profiles/{name}` | 공개 회사 프로필 |
| `/company_private/{name}` | Functions 전용 등 비공개 영역 |
| `auth_attempts/{uid}` | 인증 시도(레이트 리밋) |

---

## 메시지 타입

메시지는 `type`으로 구분됩니다. 예: `text`, `report`, `vendorReport`, `notice`, `image`, `emergency`, `dbResult`, `summary`, `maintenance` 등.

**중요**: Firestore ↔ 앱 객체 변환은 **`lib/services/message_firestore_codec.dart`만** 통해서 하도록 설계되어 있습니다. 타입별 필드(`reportData`, `imageUrls`, `emergencyType`, `noticeForRoomType` 등) 매핑을 바꿀 때는 이 파일을 기준으로 맞춥니다.

`RoomModel.roomType`(`normal`, `vendor`, `maintenance`)은 공지 필터링 등에 쓰입니다.

---

## 가상 채팅 방 998 / 999

Firestore에 문서가 없는 **로컬 전용** 개념입니다.

- **998**: 기사·차량 DB 검색 결과 UI (`dbMessageProvider` 등).
- **999**: 일일 운영 요약 / 워크 허브 (`adminMessageProvider` 등).

스트리밍 프로바이더는 이 방 ID에 대해 **빈 스트림**을 돌려주고, 방 목록에서 삭제·고정 등 일부 조작은 막혀 있습니다.

---

## 오프라인·데모 모드

Firebase 초기화에 실패하면 `AuthRepository.firebaseAvailable`이 거짓이 되고, **`utils/sample_data.dart`** 기반 등으로 동작하는 **로컬 모드**로 떨어집니다. 서비스 계층에서는 Firebase 호출 전 이 플래그를 확인하는 패턴을 따릅니다.

---

## 로컬 데이터베이스(Drift)

`lib/database/` — 스키마 버전 2, 대표 테이블:

| 테이블 | 역할 |
|--------|------|
| `CachedMessages` | 오프라인 메시지 캐시 (PK: Firestore 문서 ID) |
| `CachedRooms` | 방 메타 캐시 |
| `LocalReadState` | 방별 마지막 읽음 시각 |
| `OutboxMessages` | 전송 실패 큐 (복구 시 재시도) |

앱 시작 시 **30일 이상 된 캐시 메시지**를 정리합니다.

스키마를 바꾼 뒤에는 아래 **코드 생성** 명령을 실행합니다.

---

## 푸시 알림(FCM)

- **긴급**: 매니저/슈퍼어드민 대상, Android 채널 `crewtalk_emergency` 등 고우선 처리. **긴급은 항상 소리·진동 우선**으로 발송합니다.
- **일반 채팅**: 방에 연결된 회사 사용자에게 전송(가상 방 998/999 등은 Functions에서 스킵).
- 토큰은 `users/{uid}.fcmTokens[]`에 저장되며, Functions에서 배치로 발송합니다.
- **앱 설정「알림 소리」「진동」**: 로컬에는 `UserSessionStorage`, **백그라운드 푸시까지 맞추기 위해** 동일 값을 `users/{uid}`에 기록합니다. 로그인·토큰 동기화·설정 토글 시 `FcmPushService.syncMessageNotificationPrefsToFirestore`가 갱신합니다.
- **Cloud Functions(일반 채팅)**: 사용자별 소리·진동 조합에 따라 Android **알림 채널**(`crewtalk_messages`, `crewtalk_messages_novib`, `crewtalk_messages_silent_vib`, `crewtalk_messages_quiet`)과 iOS **APNS `sound` 포함 여부**를 나눠 발송합니다. 앱 쪽 `FcmPushService`에서 동일 id 채널을 생성해야 합니다.
- **포그라운드**: `FirebaseMessaging.onMessage` → `flutter_local_notifications`로 표시. **방별 알림 끄기**(`mutedRooms`)는 이 경로에서 해당 방 푸시를 아예 생략합니다.
- **채팅 목록 열람 중** 새 메시지 알림음: `ForegroundNotifySound` 등(설정·방 음소거와 연동).

---

## GPS 추적

- `flutter_foreground_task` + `geolocator`.
- `trackId`는 `ownerUid_timestamp` 형태 등으로 생성되고, 점은 버퍼 후 배치 기록(대략 30초 간격, 배치 상한 등 정책 있음).
- **1시간 후 자동 종료** 등 제한이 있습니다.

---

## Cloud Functions(`functions/index.js`) 요약

- `verifyCompanyPassword` — 회사 비밀번호 검증 + 실패 횟수 제한.
- `onEmergencyMessageCreated` — 긴급 FCM + `lastMessage` 등 비정규화.
- `onChatMessageCreated` — 일반 채팅 FCM(사용자 알림 소리·진동 설정 반영, 위 **푸시 알림** 절 참고).
- `adminUpsertCompany`, `adminDeleteCompany` — 회사 관리.

**런타임**: `functions/package.json`의 `engines.node`는 **20**을 가정합니다. 로컬에서 `firebase-tools`와 맞추려면 Node 20 LTS 사용을 권장합니다.

**배포**: 저장소 루트 **`.firebaserc`**에 기본 프로젝트 `crewtalk8`이 있습니다. 전역 CLI가 없으면 예:

```bash
npx firebase-tools@latest login
cd /path/to/crewtalk
npx firebase-tools@latest deploy --only functions
```

---

## 앱 초기화 흐름(`lib/main.dart` 요약)

1. 세로 고정, GPS 포그라운드 태스크 초기화  
2. Firebase 초기화 및(모바일) FCM 백그라운드 핸들러 등록  
3. 세션 복원(Firestore 또는 SharedPreferences)  
4. 로그인 사용자 FCM 토큰 동기화 및 **알림 소리·진동 설정 Firestore 반영**  
5. Drift 오래된 캐시 정리  
6. `FirestoreRoomSync`로 루트에서 방·카카오 링크·**전역 배차표 노출** 실시간 동기화 후 앱 실행  

---

## 프로젝트 디렉터리 가이드

| 경로 | 설명 |
|------|------|
| `lib/main.dart` | 진입점, 초기화 |
| `lib/router/` | Go Router 설정 |
| `lib/providers/` | Riverpod 프로바이더 |
| `lib/screens/` | 화면(채팅 등 대형 파일 포함) |
| `lib/widgets/` | 공용 위젯(`message_bubbles`, `FirestoreRoomSync` 등) |
| `lib/services/` | Firestore·Auth·FCM·GPS·이미지 캐시 등 |
| `lib/models/` | 도메인 모델 |
| `lib/database/` | Drift DB·DAO |
| `firebase/` | Firestore/Storage 규칙 등 |
| `functions/` | Cloud Functions(Node) |
| `.firebaserc` | Firebase CLI 기본 프로젝트(`crewtalk8`) |

개발자용 상세 아키텍처 메모는 저장소 루트의 **`CLAUDE.md`**에 있습니다.

---

## 개발 전 준비사항

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) 설치  
2. (실기기/실서비스) [Firebase CLI](https://firebase.google.com/docs/cli) — 전역 설치(`npm i -g firebase-tools`) 또는 `npx firebase-tools@latest` 사용. 최초 `firebase login` 필요  
3. **Android**: `google-services.json`을 `android/app/`에 두기  
4. **iOS**: `GoogleService-Info.plist`를 Xcode/`ios/Runner` 쪽에 맞게 포함  
5. `lib/firebase_options.dart`는 FlutterFire 등으로 생성·유지  

> 저장소에 위 설정 파일이 없을 수 있습니다. 클론 후 팀에서 공유받거나 Firebase 콘솔에서 내려받아 넣어야 합니다.

---

## 자주 쓰는 명령어

```bash
# 의존성
flutter pub get

# 개발 실행
flutter run

# Riverpod/Drift 코드 생성 (스키마·어노테이션 변경 후)
dart run build_runner build --delete-conflicting-outputs

# 테스트
flutter test

# 빌드
flutter build apk
flutter build ios
```

**런처 아이콘·스플래시** 이미지를 바꾼 뒤:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

Firebase 배포 예(프로젝트는 `.firebaserc` 또는 `--project crewtalk8`):

```bash
firebase deploy --only firestore:rules
firebase deploy --only functions
firebase deploy --only storage:rules
# 또는: npx firebase-tools@latest deploy --only functions
```

---

## 테스트 현황

`test/widget_test.dart`는 기본 보일러플레이트 수준이며, **실질적인 단위·통합 테스트 스위트는 아직 거의 없습니다.** 기능 추가 시 테스트를 함께 두는 것을 권장합니다.

---

## 버전

`pubspec.yaml`의 `version` 필드를 기준으로 합니다(예: `1.0.0+100`).

---

## 라이선스·비공개

`publish_to: 'none'`으로 설정되어 있어 pub.dev 배포용이 아닌 **비공개 앱**으로 관리하는 구성입니다.

---

## 더 알고 싶을 때

- **아키텍처·프로바이더·컬렉션 상세**: `CLAUDE.md`  
- **보안 규칙**: `firebase/firestore.rules`  
- **푸시·긴급 처리**: `functions/index.js`, `lib/services/fcm_push_service.dart`  

문의나 온보딩 시 위 파일과 본 README를 함께 보면 전체 그림을 빠르게 잡을 수 있습니다.
