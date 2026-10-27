/// هذا الملف يحتوي على الترقيمات (Enums) المستخدمة لتمثيل حالات اللعبة وخياراتها.

/// يمثل حالة واجهة المستخدم الحالية في لعبة لودو (قائمة، مراهنة، لعب، إلخ)
enum LudoUiState {
  menu,
  betSelection,
  matchmaking,
  playing,
  teamUpSelection,
  twoFourSelection,
  privateTableSelection,
  friendInvitation,
}

/// يحدد نمط لعب الذكاء الاصطناعي (هجومي، دفاعي، متوازن، عشوائي)
enum LudoBotPersonality { aggressive, defensive, balanced, random }

/// يحدد مستوى صعوبة الذكاء الاصطناعي
enum LudoBotDifficulty { easy, medium, hard, pro }

/// يمثل نوع الحدث الذي يتم تسجيله في سجل اللعبة
enum LudoGameLogType {
  move,
  capture,
  sixBonus,
  win,
  chat,
  sticker,
  turnChange,
  start,
  magic,
  diamondReRoll,
}
