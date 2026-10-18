import 'package:flutter/material.dart' show Icons;
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// App Icons - Core Design System
///
/// TOÀN BỘ icon của app phải lấy từ file này (không dùng `Icons.*` trực tiếp
/// trong feature). Bộ icon Phosphor có nét bo tròn, mỗi icon có bản viền
/// (không chọn) và bản đặc (đang chọn) giống cách Facebook đổi icon khi chọn
/// tab. Đổi bộ icon chỉ cần sửa file này.
///
/// Quy ước đặt tên: `xxx` = bản viền, `xxxFill` / `xxxActive` = bản đặc.
class AppIcons {
  AppIcons._();

  // ---- Tab điều hướng ----
  static const home = PhosphorIconsRegular.house;
  static const homeActive = PhosphorIconsFill.house;
  static const friends = PhosphorIconsRegular.usersThree;
  static const friendsActive = PhosphorIconsFill.usersThree;
  // Icon cũ của Material (dấu ? trên xấp giấy) - hợp với "ngân hàng đề" hơn icon Phosphor
  static const quiz = Icons.quiz_outlined;
  static const quizActive = Icons.quiz_rounded;
  static const questionMark = PhosphorIconsFill.question;
  static const notifications = PhosphorIconsRegular.bell;
  static const notificationsActive = PhosphorIconsFill.bell;
  static const menu = PhosphorIconsRegular.list;
  static const menuActive = PhosphorIconsBold.list;

  // ---- Header ----
  static const add = PhosphorIconsRegular.plus;
  static const search = PhosphorIconsRegular.magnifyingGlass;
  static const messenger = PhosphorIconsRegular.messengerLogo;

  // ---- Bài viết ----
  static const like = PhosphorIconsRegular.thumbsUp;
  static const likeFill = PhosphorIconsFill.thumbsUp;
  static const comment = PhosphorIconsRegular.chatCircle;
  static const share = PhosphorIconsRegular.shareFat;
  static const more = PhosphorIconsBold.dotsThree;
  static const audienceEveryone = PhosphorIconsFill.globeHemisphereWest;
  static const audienceFriends = PhosphorIconsFill.users;
  static const audienceOnlyMe = PhosphorIconsFill.lock;
  static const photos = PhosphorIconsRegular.images;
  static const photosFill = PhosphorIconsFill.images;
  static const camera = PhosphorIconsRegular.camera;
  static const cameraFill = PhosphorIconsFill.camera;
  static const send = PhosphorIconsFill.paperPlaneRight;
  static const play = PhosphorIconsFill.play;
  static const pause = PhosphorIconsFill.pause;
  static const playCircle = PhosphorIconsFill.playCircle;
  static const imageBroken = PhosphorIconsRegular.imageBroken;
  static const feed = PhosphorIconsFill.newspaper;
  static const article = PhosphorIconsRegular.newspaper;

  // ---- Điều hướng / thao tác chung ----
  static const back = PhosphorIconsBold.caretLeft;
  static const close = PhosphorIconsBold.x;
  static const chevronRight = PhosphorIconsBold.caretRight;
  static const dropdown = PhosphorIconsFill.caretDown;
  static const refresh = PhosphorIconsBold.arrowClockwise;
  static const edit = PhosphorIconsRegular.pencilSimple;
  static const delete = PhosphorIconsRegular.trash;
  static const flag = PhosphorIconsRegular.flag;
  static const settings = PhosphorIconsFill.gear;
  static const logout = PhosphorIconsRegular.signOut;
  static const inbox = PhosphorIconsRegular.tray;

  // ---- Tài khoản / bảo mật ----
  static const person = PhosphorIconsRegular.user;
  static const email = PhosphorIconsRegular.at;
  static const lock = PhosphorIconsRegular.lock;
  static const passwordReset = PhosphorIconsRegular.lockKey;
  static const shield = PhosphorIconsRegular.shield;
  static const shieldCheck = PhosphorIconsRegular.shieldCheck;
  static const eye = PhosphorIconsRegular.eye;
  static const eyeOff = PhosphorIconsRegular.eyeSlash;

  // ---- Thông tin hồ sơ ----
  static const school = PhosphorIconsRegular.graduationCap;
  static const schoolFill = PhosphorIconsFill.graduationCap;
  static const faculty = PhosphorIconsRegular.buildings;
  static const idCard = PhosphorIconsRegular.identificationCard;
  static const classGroup = PhosphorIconsRegular.users;
  static const joined = PhosphorIconsRegular.clock;
  static const genderMale = PhosphorIconsRegular.genderMale;
  static const genderFemale = PhosphorIconsRegular.genderFemale;
  static const emailAddress = PhosphorIconsRegular.envelopeSimple;
  static const birthday = PhosphorIconsRegular.cake;
  static const points = PhosphorIconsFill.star;
  static const badge = PhosphorIconsFill.medal;
  static const lecturer = PhosphorIconsFill.sealCheck;
  static const subject = PhosphorIconsFill.bookOpenText;
  static const trophy = PhosphorIconsFill.trophy;
  static const leaderboard = PhosphorIconsFill.ranking;
  static const shop = PhosphorIconsFill.storefront;
  static const exam = PhosphorIconsFill.fileText;
  static const bolt = PhosphorIconsFill.lightning;

  // ---- Trạng thái ----
  static const success = PhosphorIconsFill.checkCircle;
  static const error = PhosphorIconsFill.warningCircle;
  static const errorOutline = PhosphorIconsRegular.warningCircle;
  static const info = PhosphorIconsFill.info;
  static const infoOutline = PhosphorIconsRegular.info;
  static const offline = PhosphorIconsRegular.wifiSlash;
  static const radioOn = PhosphorIconsFill.radioButton;
  static const radioOff = PhosphorIconsRegular.circle;
}
