"""Preserve vendor code/resources; replace app-wide ProGuard flags with library consumer rules."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
root=Path(__file__).resolve().parents[1]
source=root.parent/'QRing_Android_SDK_1.0.0.78/qring_sdk_1.0.0.78.aar'
output=root/'android/vendor/it/tyb/vendor/qring/1.0.0.78-tyb.1'
output.mkdir(parents=True,exist_ok=True)
rules='''# QRing uses reflective command dispatch. Keep the vendor API and native entry points.
-keep class com.oudmon.** { *; }
-keep class com.realsil.** { *; }
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*
-keepclasseswithmembernames,includedescriptorclasses class * { native <methods>; }
# Optional Wi-Fi recording import is outside the plugin API and is never initialized.
-dontwarn com.androidnetworking.**
# Optional RealSil audio playback JAR references absent vendor customer-layer classes.
-dontwarn com.realsil.customer.bbpro.core.BeeError
-dontwarn com.realsil.customer.bbpro.core.transportlayer.AckPacket
-dontwarn com.realsil.customer.bbpro.core.transportlayer.Command$Builder
-dontwarn com.realsil.customer.bbpro.core.transportlayer.Command
-dontwarn com.realsil.customer.bbpro.core.transportlayer.TransportLayerPacket
-dontwarn com.realsil.customer.bbpro.internal.ModelClient
-dontwarn com.realsil.customer.bbpro.internal.ModelClientCallback
-dontwarn com.realsil.customer.core.logger.ZLogger
-dontwarn com.realsil.customer.core.utility.DataConverter
'''
with ZipFile(source) as src, ZipFile(output/'qring-1.0.0.78-tyb.1.aar','w',ZIP_DEFLATED) as dst:
    for entry in src.infolist(): dst.writestr(entry, rules if entry.filename=='proguard.txt' else src.read(entry.filename))
(output/'qring-1.0.0.78-tyb.1.pom').write_text('<project><modelVersion>4.0.0</modelVersion><groupId>it.tyb.vendor</groupId><artifactId>qring</artifactId><version>1.0.0.78-tyb.1</version><packaging>aar</packaging></project>\n')
print('Original SHA256:',hashlib.sha256(source.read_bytes()).hexdigest())
print('Derived SHA256:',hashlib.sha256((output/'qring-1.0.0.78-tyb.1.aar').read_bytes()).hexdigest())
