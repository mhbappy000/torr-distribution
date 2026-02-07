# Torr Distribution — GitHub-Ready Picker App

This repository is designed for **no-local Flutter setup**.

✅ You only upload it to GitHub. GitHub Actions will:
1. Create a Flutter project on the runner
2. Copy `app_src/` into it
3. Build an Android debug APK
4. Upload the APK as an Actions artifact

## How to use (Noob friendly)
### 1) Upload to GitHub
- Create a new GitHub repository
- Upload all files from this folder (or drag & drop)

### 2) Wait for APK
- Go to **Actions** tab in GitHub
- Open the latest workflow run
- Download the artifact: `torr-distribution-debug-apk`

### 3) Install APK on phones
- Send the downloaded `app-debug.apk` to pickers
- Install (allow "unknown sources" if prompted)

## Update your real data
Edit CSV files:
- `app_src/assets/data/products.csv`
- `app_src/assets/data/pick_tasks.csv`
- `app_src/assets/data/location_barcodes.csv`

## MVP flow
- Scan Location barcode once (e.g., `CWHTR06432`)
- Then scan product barcodes repeatedly
- Each scan = qty 1
