import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release keystore：android/key.properties（已加入 .gitignore，不入版控）
// 範本見 android/key.properties.example
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "network.ignirelay.ignirelay_app"
    compileSdk = 36
    buildToolsVersion = "36.0.0"
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "network.ignirelay"
        // minSdk 26: Health Connect (health package) 最低需求
        minSdk = 26
        // 鎖定 35 (Android 15 stable)，避免 Flutter 預設 36 (Android 16 beta) 導致安裝相容性問題
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // v0.3 Stage 0c wave 3F — instrumentation test runner for the
        // WireConformanceInstrumentationTest (reads the cross-platform
        // corpus committed at <repo>/docs/specs/wire_conformance_v1.json
        // and validates Kotlin Chunker.kt + IBLT.kt + Bloom builder
        // against the Dart oracle). Run via:
        //   ./gradlew :app:connectedDebugAndroidTest
        // See android/app/src/androidTest/ for the consumer.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // v0.3 Stage 0c wave 3F — bundle the wire conformance corpus into
    // the androidTest assets so the on-device test can read it via
    // `InstrumentationRegistry.getInstrumentation().context.assets`. The
    // .md specs in the same directory are bundled too (small text files,
    // test APK only — never shipped to users). Path resolution:
    //   rootProject.rootDir = <repo>/resqmesh_app/android/
    //   ../../docs/specs    = <repo>/docs/specs/
    sourceSets {
        getByName("androidTest").assets.srcDir(rootProject.file("../../docs/specs"))
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // 若 android/key.properties 存在則用正式簽章；否則 fallback debug，
            // 這樣 `flutter run --release` 在開發機仍可跑，但分發前會失敗提示。
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val versionName = variant.versionName
            output.outputFileName = "IgniRelay-v${versionName}-${variant.buildType.name}.apk"
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Nordic BLE Library — 跨廠牌 Android BLE 相容性（取代 flutter_blue_plus Central 角色）
    implementation("no.nordicsemi.android:ble:2.7.4")

    // v0.3 Stage 0c wave 3F — instrumentation test deps. Versions chosen
    // to match a vanilla `flutter create` Android template circa 2026Q2;
    // do not bump without verifying compileSdk=36 / minSdk=26 still works.
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
}

flutter {
    source = "../.."
}
