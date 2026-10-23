plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.rnd_text_to_speech"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.rnd_text_to_speech"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // x86/x86_64 သည် PC emulator အတွက်သာ — ဖုန်းအစစ်မရှိဘဲ ONNX Runtime + Flutter engine ကြောင့် APK ကို ~50–60 MB တိုးစေသည်။
    // `ndk.abiFilters` ကို မသုံးခြင်းမှာ `flutter build apk --split-per-abi` (splits.abi) နှင့် ပဋိပက္ခဖြစ်သောကြောင့်။
    // x86_64 emulator ဖြင့် စမ်းလိုပါက ဤ exclude ကို ယာယီ ဖယ်ပါ (Apple silicon emulator သည် arm64 ဖြစ်၍ မလို)။
    packaging {
        jniLibs {
            excludes += listOf("lib/x86/**", "lib/x86_64/**")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
