---
description: UE C++ のバージョン非依存の規則
paths:
  - "**/Source/**/*.h"
  - "**/Source/**/*.cpp"
  - "**/Plugins/**/*.h"
  - "**/Plugins/**/*.cpp"
---

- `.generated.h` の include は必ず最後に置く
- UObject 派生への参照をメンバに持つときは `UPROPERTY()` を付ける。付けない生ポインタは GC に追跡されず不正参照になる
- メンバ宣言のオブジェクト参照は `TObjectPtr<T>` を使う
- `check()` の引数は Shipping ビルドで評価されない。副作用のある式を渡さない
- 文字列は用途で選ぶ。内部 ID は `FName`、可変文字列は `FString`、表示文字列は `FText`
- ログは `UE_LOG` と専用カテゴリを使う。`printf` / `std::cout` を使わない
- UObject の生成・破棄・プロパティ変更はゲームスレッドで行う
- `TArray` の要素への参照・ポインタは、要素追加による再確保で無効化される
