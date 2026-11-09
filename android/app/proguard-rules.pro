# ML Kit text recognition: языковые опции вынесены в отдельные артефакты,
# которые проект не подключает. R8 считает их missing classes, поэтому
# подавляем предупреждения.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# RuStore Push SDK: Parcelable-классы передаются в приложение RuStore по IPC —
# R8 не должен их переименовывать (правило из документации RuStore).
-keep public class com.vk.push.** extends android.os.Parcelable
