/// ゲーム種別を表す定数クラス。
///
/// DBや JSON に保存される文字列値を一元管理する。
/// 'free' / 'set' のハードコード文字列はすべてここを参照すること。
class GameType {
  GameType._();

  static const String free = 'free';
  static const String set  = 'set';

  /// 表示用ラベルを返す。
  static String label(String type) =>
      type == free ? 'フリー' : 'セット';
}
