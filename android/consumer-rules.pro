# PushPushGo SDK - ProGuard/R8 rules
# These rules are automatically included in consuming apps

# Huawei HMS - Optional dependency, not required for FCM-only apps
-dontwarn com.huawei.agconnect.**
-dontwarn com.huawei.hms.**
