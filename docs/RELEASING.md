# Releasing

How to produce a build for Google Play. See `PLAY-LISTING.md` for the Console
side.

---

## 1. Create the upload keystore — once, and never again

Google Play signs the app that reaches users. What you upload is signed with an
**upload key**, which proves the bundle came from you.

Generate it somewhere **outside this repository**:

```bat
mkdir C:\Users\paulj\keys
keytool -genkey -v ^
  -keystore C:\Users\paulj\keys\kylesvoice-upload-keystore.jks ^
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` ships with the JDK. If it is not on your PATH:

```
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
```

It will ask for a password and some identifying details. The details are not
shown to users; the password matters.

### Back it up now, not later

If you lose this keystore you cannot upload an update to the same listing. Play
App Signing does allow an upload key to be **reset** by contacting Google, so it
is not the catastrophe it once was — but it is a support round-trip you do not
want mid-crisis.

Put a copy somewhere that is not this laptop: a password manager, an encrypted
drive, or a printout of the file in a safe place. Store the password separately
from the file.

**The keystore and its password must never be committed.** `.gitignore` already
covers `*.jks` and `key.properties`, but the responsibility is yours.

## 2. Point the build at it

Copy the template and fill it in:

```bat
copy app\android\key.properties.example app\android\key.properties
```

```properties
storePassword=<the password you chose>
keyPassword=<usually the same>
keyAlias=upload
storeFile=C:/Users/paulj/keys/kylesvoice-upload-keystore.jks
```

Forward slashes work on Windows here and avoid escaping problems.

**If `key.properties` is absent, release builds still work** but are signed with
the debug key. They will install and run on a device and Play will reject them.
That is deliberate: anyone can clone this repository and build a working app
without needing your signing key.

## 3. Build the bundle

Play wants an Android App Bundle, not an APK:

```bat
cd app
flutter build appbundle --release
```

Output:

```
app\build\app\outputs\bundle\release\app-release.aab
```

Confirm it was signed with the upload key rather than the debug key:

```bat
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

The owner should be the details you entered in step 1, **not** `CN=Android
Debug`.

## 4. Version numbers

Set in `app/pubspec.yaml`:

```yaml
version: 1.0.0+1
```

The part before `+` is the version name users see. The part after is the version
code, which **must increase with every upload** and can never be reused, even
for a bundle that was rejected.

## 5. Upload

Start on the **internal testing** track, not production. It reaches only testers
you list, appears within minutes rather than days, and lets you put the real
build on Kyle's tablet through the Play flow before anyone else can find it.

Promote to production only once it has been used on his actual device.

---

## Checking what you are shipping

Worth running before any upload, because the answers belong in the Data safety
form and should not drift:

```bat
:: Permissions actually declared in the release build
aapt2 dump permissions app\build\app\outputs\flutter-apk\app-release.apk

:: Should list the package and nothing else of substance
```

The release build requests **no Android platform permission at all**, and
notably no `INTERNET`. The only `uses-permission` line is the app's own
`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, which AndroidX Core defines at
signature level to keep an app's dynamic receivers private to itself; it grants
nothing and is not shown to users.

If a real permission ever appears, the privacy policy and the Data safety
declaration must change with it, in the same commit.

## Fire tablets

Google Play cannot reach a stock Fire tablet. Kyle's has the Play Store
sideloaded, so it can receive Play builds, but other families will not. For them:

- **GitHub Releases** — attach the APK (`flutter build apk --release`) to a
  tagged release. Works on any Android or Fire device.
- **Amazon Appstore** — the route that reaches stock Fire tablets properly.

See `ROADMAP.md` for the full distribution plan.
