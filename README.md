# Clap Up Down

Processing Android prototype plus a browser version that can run as a live web app.

## What is included

- `web/` is a mobile-friendly browser version with microphone clap detection and device motion selection.
- `android-processing/clap_up_down/` is the original Processing Android sketch, including the manifest and sketch properties.
- `.github/workflows/pages.yml` deploys the web app to GitHub Pages when this project is pushed to `main`.

## Run the web app locally

```bash
npm install
npm run dev
```

Open the local URL from Vite. Use a phone for the real mic and motion flow. On desktop, the test controls and keyboard shortcuts are useful for checking the trial logic:

- Space: clap
- Up arrow: phone up
- Down arrow: phone down

## Publish the live web app

1. Push this repository to GitHub.
2. In the GitHub repository, open Settings > Pages.
3. Set Build and deployment to GitHub Actions if it is not already selected.
4. Push to `main`; the included workflow will publish the `web/` folder.

## Run the Android app

1. Install Processing with Android Mode.
2. Install the Ketai library in Processing.
3. Open `android-processing/clap_up_down/clap_up_down.pde`.
4. Connect an Android phone with USB debugging enabled.
5. Run from Processing Android Mode.

The Android app requests microphone access through `AndroidManifest.xml` and uses Ketai accelerometer callbacks for up/down selection.
