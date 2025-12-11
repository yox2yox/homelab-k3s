# 設計書の修正

指定された設計書を**CLAUDE.mdの設計書作成ガイドライン**に従って自動修正します。

## 修正内容

以下の観点で自動的に修正を行います：

### 1. コード例の簡略化
- 完全な実装コード（15行超）を見つけたら、インターフェース定義や型定義に置き換える
- 重要な概念のみを残し、実装詳細は削除する
- コメントで処理フローを補足する

### 2. 構成の改善
- 概要と目的が不足していれば追加
- 責務と役割を明確化
- 複雑な説明は図や表で視覚化

### 3. 説明の重点調整
- 「なぜ」の説明を強化
- 「どのように」の詳細を削減
- トレードオフや代替案の説明を追加

## 修正プロセス

1. **現状分析**: ドキュメントを読み取り、問題点を特定
2. **修正計画**: どの部分をどう修正するか計画を提示
3. **ユーザー確認**: 修正計画をユーザーに確認
4. **修正実行**: 承認後、実際に修正を適用

## 注意事項

⚠️ このコマンドは**プランモード**で実行されます。
- まず修正計画を提示し、ユーザーの承認を得てから修正します
- 元のファイルは上書きされるため、事前にgit commitを推奨します

## 使用方法

```bash
# 特定の設計書を修正
/fix-design-doc docs/design/backend/01-architecture.md

# または、現在開いているファイルを修正
/fix-design-doc
```

## 修正例

### Before（悪い例）
```typescript
// 50行の完全な実装コード
export class CardService {
  async createCard(userId: string, cardData: CreateCardInput): Promise<CustomCard> {
    // バリデーション
    if (!cardData.name) throw new Error('Name required');
    if (cardData.name.length > 30) throw new Error('Name too long');

    // 画像検証
    const image = await ImageModel.findByUrl(cardData.imageUrl);
    if (!image) throw new Error('Invalid image');

    // データベース保存
    const card = await CardModel.create({
      userId,
      name: cardData.name,
      description: cardData.description,
      // ...さらに長い実装が続く
    });

    return card;
  }
}
```

### After（良い例）
```typescript
// services/cardService.ts
export class CardService {
  // カード作成: バリデーション → 画像検証 → DB保存
  async createCard(userId: string, cardData: CreateCardInput): Promise<CustomCard>

  // カード取得: ユーザーIDで絞り込み
  async getUserCards(userId: string): Promise<CustomCard[]>
}

// バリデーションはZodスキーマで実施
// 詳細実装は src/services/cardService.ts を参照
```
