# Stripe Proguard Rules
-dontwarn com.stripe.android.pushProvisioning.**
-keep class com.stripe.android.pushProvisioning.** { *; }

# Flutter Stripe / React Native Stripe bridge rules
-dontwarn com.reactnativestripesdk.**
-keep class com.reactnativestripesdk.** { *; }
