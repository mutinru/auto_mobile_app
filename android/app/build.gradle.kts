import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Релизный ключ — android/key.properties (в .gitignore; на машине разработчика
// это ссылка на ~/keys/bitnebit/key.properties). Его SHA-256 указан в RuStore
// для пушей: другой ключ — и пуш-токен не выдадут, а обновление не встанет.
// Нет файла — devRelease подписывается отладочным ключом (для эмулятора), а
// prodRelease не собирается вовсе (проверка ниже, ревью №36).
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

android {
    namespace = "com.indigolab.auto_podbor_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications требует desugaring (java.time на старых Android)
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.indigolab.auto_podbor_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        buildConfig = true
        // resValue — схема возврата SDK ЮKassa (ym_app_scheme) у флейворов
        resValues = true
    }

    flavorDimensions += "env"

    // RUSTORE_PUSH_PROJECT_ID — ID проекта пушей из RuStore Консоли
    // (Push-уведомления → Проекты). Не секрет: он и так в APK. Проект привязан
    // к applicationId и SHA-256 ключа подписи, поэтому у dev (отладочный ключ)
    // его нет — там пуши только через Firebase. Пусто — RuStore выключен.
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "com.bitnebit.dev"
            buildConfigField("String", "RUSTORE_PUSH_PROJECT_ID", "\"\"")
            // схема возврата из банка после SberPay и СБП (SDK ЮKassa); у dev
            // своя — иначе на телефоне с обеими сборками Android спросит, куда
            resValue("string", "ym_app_scheme", "bitnebitdev")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.bitnebit.app"
            resValue("string", "ym_app_scheme", "bitnebit")
            buildConfigField("String", "RUSTORE_PUSH_PROJECT_ID", "\"s91Xpi0VAe7XhuVTkZPktBSis9w3nkaC\"")
        }
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// prodRelease уходит в магазины: отладочная подпись или номер сборки 1
// (собрали не через make, без --build-number) там — отказ или, хуже, сборка
// у тестировщиков, которую нельзя обновить. Падаем сразу и понятно.
// Ловим упаковку, а не любую задачу с ProdRelease в имени: в графе
// devRelease бывает служебная preProdReleaseBuild.
val prodReleasePackaging = Regex("^(assemble|bundle|package)ProdRelease$")
gradle.taskGraph.whenReady {
    if (allTasks.none { prodReleasePackaging.matches(it.name) }) return@whenReady
    if (!hasReleaseKey) {
        throw GradleException(
            "prodRelease без релизного ключа: нет android/key.properties. " +
                "Сделайте ссылку на ~/keys/bitnebit/key.properties (ключ — " +
                "у владельца проекта); отладочным ключом prod не подписываем.",
        )
    }
    if (flutter.versionCode == 1) {
        throw GradleException(
            "prodRelease с номером сборки 1: собирайте через make " +
                "(make build-appbundle-prod) — он передаёт --build-number.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // SDK пушей RuStore — для ручной инициализации в BitNeBitApplication.
    // Версия — та же, что у плагина flutter_rustore_push (его build.gradle).
    implementation("ru.rustore.sdk:pushclient:7.5.0")
}
