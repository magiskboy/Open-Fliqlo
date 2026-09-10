# Performance optimizations review (mục 1–5)

Tài liệu mô tả các tối ưu **còn lại** sau khi đã làm:

- `RepaintBoundary` quanh từng digit / colon
- Scale theo kích thước layout (bỏ `Transform.scale` cả row)
- Không `notifyListeners` khi chỉ giây đổi mà `showSeconds == false`

Mục tiêu: giảm CPU/GPU khi flip, giảm wake timer, giảm I/O settings — đặc biệt trên mobile / screensaver.

---

## Mục lục

1. [Cache glyph / `Picture` trong `FlipDigitPainter`](#1-cache-glyph--picture-trong-flipdigitpainter)
2. [Timer căn wall-clock](#2-timer-căn-wall-clock)
3. [Bỏ / lazy `FlipStateMap` trên hot path](#3-bỏ--lazy-flipstatemap-trên-hot-path)
4. [Debounce ghi `SharedPreferences`](#4-debounce-ghi-sharedpreferences)
5. [Bỏ `setState` thừa trong `_onSettingsChanged`](#5-bỏ-setstate-thừa-trong-_onsettingschanged)

---

## Đã làm (ngữ cảnh)

| Thay đổi | File chính | Hiệu ứng |
|----------|------------|----------|
| `RepaintBoundary` per digit/colon | `packages/fliqlo_ui/lib/src/clock_face.dart` | Digit/colon tĩnh không bị raster lại khi digit khác flip |
| Scale vào `digitWidth` / `digitHeight` | cùng file | Layer cache ổn định hơn so với scale cả row |
| Ignore second churn khi ẩn giây | `packages/fliqlo_core/lib/src/clock_engine.dart` | Không rebuild/raster mỗi giây khi chỉ hiện H:M |

---

## 1. Cache glyph / `Picture` trong `FlipDigitPainter`

### Vấn đề hiện tại

Trong `packages/fliqlo_ui/lib/src/flip_digit.dart`, mỗi lần vẽ digit gọi `_paintDigit`, và **mỗi lần** tạo + `layout()` một `TextPainter` mới:

```dart
void _paintDigit(Canvas canvas, Size size, int digit) {
  final text = TextPainter(
    text: TextSpan(text: '$digit', style: TextStyle(
      fontSize: size.height * 0.70,
      fontFamily: FliqloTheme.digitFontFamily,
      // ...
    )),
    textDirection: TextDirection.ltr,
  )..layout();
  text.paint(canvas, /* centered offset */);
}
```

Trong một frame flip, `_paintDigit` được gọi nhiều lần:

- Nửa trên digit `to` (static)
- Nửa dưới digit `from` (static)
- Flap đang quay (`from` hoặc `to`)

Với `showSeconds: true`, mỗi giây có thể có 1–2 digit animate ~500ms @ ~60fps → hàng trăm lần layout text/giây trên các digit đang flip.

`RepaintBoundary` **không** giúp path này: digit đang flip *phải* repaint mỗi frame.

### Đề xuất

Cache theo khóa ổn định, ví dụ `(digit, fontSize)` hoặc `(digit, width, height)`:

**Phương án A — cache `TextPainter` (đơn giản hơn)**

- Map tĩnh / instance cache: `0..9` → `TextPainter` đã `layout()` với `fontSize` hiện tại.
- Invalidate khi `size` (fontSize) đổi (resize cửa sổ, đổi scale).
- Trong `paint`, chỉ `text.paint(canvas, offset)`.

**Phương án B — cache `ui.Picture` (rẻ hơn khi draw)**

- Pre-record một `Picture` cho mỗi digit ở kích thước hiện tại (glyph đã rasterize vào display list).
- `canvas.drawPicture(picture)` mỗi lần cần.
- Invalidate cùng điều kiện size.

**Gợi ý triển khai**

- Giữ cache ở `_FlipDigitState` hoặc một `DigitGlyphCache` shared theo `Size` (làm tròn fontSize để tránh thrash).
- Prewarm `0..9` lần đầu nhận size ổn định (`LayoutBuilder` / sau frame đầu).
- Không cache theo `progress` — chỉ cache glyph tĩnh; flap vẫn dùng transform canvas.

### Impact / risk

| | |
|--|--|
| **Impact** | Cao khi digit đang animate (đặc biệt bật giây) |
| **Effort** | Trung bình |
| **Risk** | Thấp nếu invalidate đúng khi size/theme đổi; cần dispose `Picture` nếu dùng B |
| **Đo** | Profile lúc flip: so CPU time trong `FlipDigitPainter.paint` / frame raster trước–sau |

### Acceptance criteria

- [ ] Không gọi `TextPainter..layout()` mỗi frame flip khi size không đổi
- [ ] Đổi scale / resize vẫn render đúng kích thước
- [ ] Visual flip không đổi so với hiện tại
- [ ] Test widget / golden (nếu có) vẫn pass

---

## 2. Timer căn wall-clock

### Vấn đề hiện tại

`ClockEngine._restartTimer`:

```dart
final interval =
    _showSeconds ? const Duration(milliseconds: 200) : const Duration(seconds: 1);
_timer = Timer.periodic(interval, (_) => _tick());
```

Hệ quả:

| Mode | Hành vi | Hệ quả |
|------|---------|--------|
| `showSeconds: true` | Wake ~5 lần/giây | Phần lớn `_tick` early-return, nhưng isolate vẫn thức |
| `showSeconds: false` | Wake mỗi 1s | Sau fix notify: không rebuild UI mỗi giây, nhưng timer vẫn chạy; phút có thể lệch tới ~1s so với đồng hồ tường |

`Timer.periodic` không căn mốc `:00` giây thật — chỉ đếm từ lúc `start()`.

### Đề xuất

Dùng **one-shot** (hoặc schedule lại sau mỗi tick) tới đúng boundary tiếp theo:

```text
now = DateTime.now()
if showSeconds:
  delay = Duration(milliseconds: 1000 - now.millisecond)
  // optionally + microsecond align
else:
  // tới phút kế: còn (60 - second) giây, trừ phần lẻ hiện tại
  delay = Duration(seconds: 60 - second) - Duration(milliseconds: now.millisecond)
```

Sau `_tick`, schedule lại timer kế tiếp (không dùng `periodic` cố định).

**Chi tiết cần lưu ý**

- Clock giả trong test (`clock: () => ...`) — delay nên dựa trên `_clock()`, không hardcode `DateTime.now()` nếu muốn test deterministic; hoặc inject scheduler.
- Drift: mỗi lần schedule từ wall time mới → tự chỉnh, tránh tích lũy lỗi.
- Khi `updateOptions(showSeconds: ...)` → cancel + schedule lại đúng mode.
- Có thể thêm margin nhỏ (ví dụ 5–16ms) sau boundary để chắc `DateTime` đã sang giây/phút mới trên mọi OS.

### Impact / risk

| | |
|--|--|
| **Impact** | Trung bình — ít wake hơn (đặc biệt mode có giây); sync phút/giây chính xác hơn |
| **Effort** | Thấp–trung bình |
| **Risk** | Trung bình nếu sai align (nhảy giây trễ / tick kép); cần test kỹ với fake clock |
| **Đo** | Log/đếm số lần `_tick` / phút; so độ lệch với wall clock; battery / wake lock ít liên quan trực tiếp hơn mục 1 nhưng tốt cho idle |

### Acceptance criteria

- [ ] `showSeconds: true`: khoảng 1 wake hữu ích / giây (không còn ~5)
- [ ] `showSeconds: false`: khoảng 1 wake / phút (hoặc rất ít), UI cập nhật sát đổi phút
- [ ] Bật/tắt giây không làm timer chồng hoặc dừng hẳn
- [ ] Unit test với fake clock / fake timer cover boundary

---

## 3. Bỏ / lazy `FlipStateMap` trên hot path

### Vấn đề hiện tại

Mỗi lần `_tick` **thành công** (có notify), engine:

1. Loop mọi `DigitSlot` build `nextFlips`
2. Gán `_flips = nextFlips`
3. Đưa `flips: Map.unmodifiable(_flips)` vào `ClockSnapshot`

Trong khi **UI không đọc** `snapshot.flips` / `flipFor` — animation `from`/`to`/`progress` hoàn toàn thuộc `FlipDigit` + `AnimationController` (đã ghi chú trong docstring engine).

Mỗi notify → allocate `Map` + nhiều `FlipState` + `unmodifiable` wrapper → áp lực GC không cần thiết, đặc biệt khi bật giây (notify mỗi giây).

### Đề xuất

**Phương án A — bỏ khỏi hot path UI (khuyến nghị)**

- Ngừng build `FlipStateMap` trong `_tick` nếu không còn consumer.
- Giữ API `flipFor` chỉ khi test/engine API cần: build lazy khi gọi, hoặc chỉ populate trong test helper.
- Nếu `ClockSnapshot.flips` là public API package: deprecate, hoặc để map rỗng / optional.

**Phương án B — lazy**

- `ClockSnapshot` giữ digits; `flips` getter compute on demand từ previous+current (cần giữ previous digits).
- Phức tạp hơn A nếu ít ai gọi.

**Phương án C — chỉ build slot đổi**

- Vẫn có map nhưng chỉ entry cho slot `from != to`.
- Giảm allocate một phần; vẫn thừa nếu UI không dùng.

### Impact / risk

| | |
|--|--|
| **Impact** | Thấp–trung bình (GC / allocate mỗi tick), rõ hơn khi `showSeconds: true` |
| **Effort** | Thấp nếu không có consumer bên ngoài; trung bình nếu phải giữ API tương thích |
| **Risk** | Phá test / API nếu có code ngoài app đọc `flips` — cần grep toàn repo + changelog |
| **Đo** | Allocation timeline trong DevTools Memory / profile GC khi bật giây |

### Acceptance criteria

- [ ] Hot path `_tick` không tạo full `FlipStateMap` (hoặc tương đương zero-cost)
- [ ] `FlipDigit` animation không đổi hành vi
- [ ] Test core cập nhật / vẫn cover transition digit nếu cần API flips
- [ ] Không regress `force: true` resettlement khi đổi 12/24h

---

## 4. Debounce ghi `SharedPreferences`

### Vấn đề hiện tại

`SettingsSheet` gọi `onChanged` trên **mọi** tick của `Slider` (dim, scale):

```dart
Slider(
  onChanged: (v) => onChanged(settings.copyWith(dim: v)),
);
```

`ClockScreen` → `_store.update(s)` → `notifyListeners()` **và** ghi ngay 6 key:

```dart
await Future.wait([
  p.setBool(...),
  p.setDouble(_kDim, next.dim),
  p.setDouble(_kScale, next.scale),
  // ...
]);
```

Khi kéo scale/dim:

- Hàng chục lần ghi disk / giây
- Mỗi lần notify → clock dưới sheet rebuild (scale đổi layout digit — đắt hơn dim)
- Trên mobile dễ gây jank ngắn khi drag

### Đề xuất

Tách **preview UI** và **persist**:

1. **`notifyListeners` / cập nhật memory ngay** — slider vẫn mượt, clock preview realtime.
2. **Persist debounce** — ví dụ 200–300ms sau lần `update` cuối, hoặc chỉ persist trong `Slider.onChangeEnd`.

Gợi ý API:

```dart
// Memory + notify ngay; schedule persist
Future<void> update(FliqloSettings next, {bool persist = true});

// hoặc
void applyLocal(FliqloSettings next);
Future<void> flush();
```

Sheet:

```dart
Slider(
  onChanged: (v) => onChanged(settings.copyWith(scale: v)),      // local
  onChangeEnd: (v) => onPersist?.(settings.copyWith(scale: v)), // disk
);
```

Toggle bool có thể persist ngay (ít sự kiện).

### Impact / risk

| | |
|--|--|
| **Impact** | Trung bình khi mở settings và kéo slider; ít ảnh hưởng screensaver idle |
| **Effort** | Thấp |
| **Risk** | App kill giữa debounce → mất lần chỉnh cuối (mitigate: flush `onChangeEnd` + `dispose`) |
| **Đo** | Đếm số `setDouble` khi drag 1s; so frame time lúc kéo scale |

### Acceptance criteria

- [ ] Kéo dim/scale: UI cập nhật mượt, không ghi prefs mỗi micro-step
- [ ] Thả tay / đóng sheet: giá trị cuối được persist
- [ ] Mở lại app: settings đúng giá trị đã lưu
- [ ] Toggle (24h, seconds, flaps, landscape) vẫn persist đúng

---

## 5. Bỏ `setState` thừa trong `_onSettingsChanged`

### Vấn đề hiện tại

`ClockScreen`:

```dart
void _onSettingsChanged() {
  final s = _store.settings;
  _engine?.updateOptions(
    use24Hour: s.use24Hour,
    showSeconds: s.showSeconds,
  );
  if (s.forceLandscape != _forceLandscapeApplied) {
    _applyOrientation(s.forceLandscape);
  }
  setState(() {});  // ← thừa với ListenableBuilder bên dưới
}
```

Body clock đã rebuild qua:

```dart
ListenableBuilder(
  listenable: Listenable.merge([_engine!, _store]),
  builder: (context, _) => ClockFace(...),
);
```

Settings sheet cũng có `ListenableBuilder(listenable: _store, ...)`.

Mỗi thay đổi settings → `_store.notifyListeners()` **và** `setState` trên `ClockScreen` → **rebuild cả subtree** `Focus` / `GestureDetector` / `Scaffold` bên ngoài, trong khi `ListenableBuilder` đã cập nhật phần clock.

### Đề xuất

```dart
void _onSettingsChanged() {
  final s = _store.settings;
  _engine?.updateOptions(
    use24Hour: s.use24Hour,
    showSeconds: s.showSeconds,
  );
  if (s.forceLandscape != _forceLandscapeApplied) {
    _applyOrientation(s.forceLandscape);
  }
  // Không setState — ListenableBuilder(_store) lo UI.
}
```

Nếu sau này có state local phụ thuộc settings mà **không** nằm trong `ListenableBuilder`, chỉ `setState` khi state local đó đổi (ví dụ flag orientation đã apply — hiện không cần vì không hiển thị từ `build`).

### Impact / risk

| | |
|--|--|
| **Impact** | Thấp–trung bình; rõ khi kéo slider (giảm một vòng rebuild ngoài) |
| **Effort** | Rất thấp (xóa vài dòng) |
| **Risk** | Rất thấp — verify không có nhánh `build` đọc settings ngoài `ListenableBuilder` |
| **Đo** | Widget rebuild count (DevTools) khi đổi một setting |

### Acceptance criteria

- [ ] Đổi mọi setting: UI clock + sheet vẫn cập nhật đúng
- [ ] Không còn double rebuild `ClockScreen` cho cùng một `notify` của store
- [ ] Orientation `forceLandscape` vẫn apply khi toggle

---

## Thứ tự đề xuất khi implement

| Ưu tiên | Mục | Lý do |
|--------:|-----|--------|
| 1 | Mục 5 | Rẻ, an toàn, làm trước vài phút |
| 2 | Mục 4 | Cùng khu settings; trải nghiệm kéo slider tốt ngay |
| 3 | Mục 2 | Idle / sync thời gian; bổ sung fix “không notify mỗi giây” |
| 4 | Mục 3 | Dọn hot path allocate; làm cùng lúc đụng `ClockEngine` với mục 2 |
| 5 | Mục 1 | Impact cao nhất lúc flip; effort lớn hơn — nên có baseline profile trước/sau |

---

## Cách đo chung (trước / sau)

1. `flutter run --profile` trên thiết bị thật (tránh debug).
2. **Repaint Rainbow** — xác nhận vẫn chỉ digit đang flip đổi màu (đã có từ `RepaintBoundary`).
3. **DevTools → Performance** — so UI/Raster ms lúc:
   - Idle, `showSeconds: false` (kỳ vọng gần như không frame mỗi giây)
   - Flip phút / flip giây
   - Kéo scale trong settings
4. (Tuỳ chọn) log số lần `_tick` / `notifyListeners` / `SharedPreferences.set*` trong debug.

---

## Ngoài phạm vi tài liệu này

- Rẻ hóa shadow `LinearGradient.createShader` mỗi frame flip (bổ sung mục 1)
- GNOME multi-monitor `Clutter.Clone`
- Tách rebuild theo từng slot digit (ROI thấp sau `RepaintBoundary` + fix notify giây)
