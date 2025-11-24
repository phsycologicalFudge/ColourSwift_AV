plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
        import java.io.FileInputStream

        def localSigningFile = rootProject.file("local-signing.properties")
def hasLocalSigning = localSigningFile.exists()
def localSigningProps = new Properties()
if (hasLocalSigning) {
    localSigningProps.load(new FileInputStream(localSigningFile))
}

android {
    namespace = "com.colourswift.cssecurity"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.colourswift.cssecurity"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasLocalSigning) {
            create("release") {
                keyAlias = localSigningProps["keyAlias"]
                keyPassword = localSigningProps["keyPassword"]
                storeFile = file(localSigningProps["storeFile"])
                storePassword = localSigningProps["storePassword"]
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false

            if (hasLocalSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.android.billingclient:billing-ktx:6.2.0")
}
