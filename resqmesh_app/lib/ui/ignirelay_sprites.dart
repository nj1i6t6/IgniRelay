import 'dart:convert';
import 'dart:typed_data';

import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

/// 每個 sprite 的尺寸 (px)
const int _spriteSize = 28;

/// sprite 間的間距
const int _pad = 2;

/// 預先生成的 sprite atlas PNG (148 x 28 px, 5 個彩色圓 + 白色十字)
/// 順序：hospital(紅) → police(藍) → school(橘) → pharmacy(紫) → grocery(綠)
const String _atlasBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAJQAAAAcCAYAAACH35ZhAAACSklEQVR42u2bwW3DMAxFvYAnyADN'
    'IAZ67sk7eAdt0IMH6KUb9OQRCniRruHaQAo4xqdM0pQOxRfAS2DlwcALxVBS0yjHsiztGt0awxrp'
    'EcPjs7YpNMj9Z9z1y/o1puV8bM/05JIrgTYz58U+tjkdueTuYQl90/f9DkMYyfGSkNu+fsIozf15'
    'a2CU5n68fMEozb2932Bc4q4PjhqJlHKNhpccNRIp5XJzJYmUcrm5kkRKudxcSSKlXKPJXKtMglTJ'
    '+ouxyiRIZeZaZRKkMnOtMglSmblWmQSpUm5NvSyTIFV3spZflkmQSs31yiRIpeZ6ZRKkUnO9MglS'
    'dQg4R8kEpJozLzpHyQSkUnGvygSkUnGvygSkUnGvygSkmtFfx1CZgFS98Jc1VCYgVZYbJROQKsuN'
    'kglIleVGyQSkynKjZAJS9XvgVEGoCbzoVEGoLLegUFluQaGy3IJCTfsOqal28jz7582hM2uqnTzP'
    'nnEtkjhqKZFrkcRRS4lciySOWqp9KtasWceRpTpUJFqzjiNLQa416ziyFORas44jS0GuNes4slT3'
    'PPZraAk17F50qCgU5FYQCnIrCAW5FYQannolhqVL3UU/zE2oJ2JYutRd9MNcyDUsXeou+mEu5BqW'
    'LnUX/TAXcg1Ll7qLfpibKBSFCheKSx6XvNAlj0U5i/LQopxtA7YN4toGbGyysfna2OTWC7dewrde'
    'uDnMzeHQzWEeX+HxlfDjKzxgxwN2oQfs+AowjwCHHwHmJQVeUgi/pMBrReSW5PLiI7lFuLyaTa5q'
    '/AKSru08d0+xwwAAAABJRU5ErkJggg==';

/// Sprite 名稱列表（與 atlas 中的順序一致）
const _spriteNames = [
  'resq_hospital', // x=0
  'resq_police', // x=30
  'resq_school', // x=60
  'resq_pharmacy', // x=90
  'resq_grocery', // x=120
];

/// 建立 [SpriteStyle]，包含預先生成的彩色圓形圖標 atlas 與索引。
SpriteStyle? buildIgniRelaySprites() {
  try {
    final sprites = <String, Sprite>{};
    int x = 0;

    for (final name in _spriteNames) {
      sprites[name] = Sprite(
        name: name,
        x: x,
        y: 0,
        width: _spriteSize,
        height: _spriteSize,
        pixelRatio: 1,
        stretchX: [],
        stretchY: [],
      );
      x += _spriteSize + _pad;
    }

    // PNG 已預先生成，直接解碼 base64，無需 dart:ui
    final Uint8List atlasBytes = base64Decode(_atlasBase64);

    return SpriteStyle(
      atlasProvider: () async => atlasBytes,
      index: SpriteIndex(sprites),
    );
  } catch (e) {
    // Sprite 載入失敗不應阻止地圖渲染（在舊 GPU 上可能不支援）
    // 地圖仍可正常顯示，只是不會有 POI 圖標
    return null;
  }
}
