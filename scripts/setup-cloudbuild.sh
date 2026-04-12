#!/usr/bin/env bash
# One-time Cloud Build setup.
# Must be run by a GCP project OWNER (or Editor) — not the cloud-build SA.
#
# Usage:
#   gcloud auth login   # login as a project owner
#   bash scripts/setup-cloudbuild.sh

set -euo pipefail

# Find gcloud in common install locations
for dir in \
    "$HOME/google-cloud-sdk/bin" \
    "/usr/local/google-cloud-sdk/bin" \
    "/opt/google-cloud-sdk/bin" \
    "/tmp/google-cloud-sdk/bin" \
    "/usr/lib/google-cloud-sdk/bin"; do
  if [ -x "$dir/gcloud" ]; then
    export PATH="$dir:$PATH"
    break
  fi
done

if ! command -v gcloud &>/dev/null; then
  echo "gcloud not found. Install it: https://cloud.google.com/sdk/docs/install"
  exit 1
fi

PROJECT_ID="project-b882ddad-b8b1-4a5c-908"
PROJECT_NUMBER="85726111298"
SA="cloud-build@${PROJECT_ID}.iam.gserviceaccount.com"

DOCKERHUB_USERNAME="fswillis99"
DOCKERHUB_TOKEN="dckr_pat_ZjpcY6x4viPh2FgN_Vw_dLLAe2k"

gcloud config set project "$PROJECT_ID"

echo "=== Enabling APIs ==="
gcloud services enable cloudbuild.googleapis.com secretmanager.googleapis.com
echo "Waiting for Cloud Build SA to be provisioned..."
sleep 15

echo "=== Granting cloud-build SA the roles it needs ==="
# Submit builds
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA}" \
  --role="roles/cloudbuild.builds.editor"

# Upload source to GCS
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA}" \
  --role="roles/storage.admin"

# Allow the Cloud Build runner (Compute SA) to read uploaded source
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${COMPUTE_SA}" \
  --role="roles/storage.objectViewer"

# Allow cloud-build SA to act as any SA the build runs under
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA}" \
  --role="roles/iam.serviceAccountUser"


echo "=== Creating Docker Hub credentials in Secret Manager ==="
# The Cloud Build runner SA needs to read these secrets
CB_RUNNER="service-${PROJECT_NUMBER}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

for SECRET_NAME in dockerhub-username dockerhub-token; do
  if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" &>/dev/null; then
    echo "Secret $SECRET_NAME already exists, skipping create."
  else
    case "$SECRET_NAME" in
      dockerhub-username) VALUE="$DOCKERHUB_USERNAME" ;;
      dockerhub-token)    VALUE="$DOCKERHUB_TOKEN" ;;
    esac
    echo -n "$VALUE" | gcloud secrets create "$SECRET_NAME" \
      --project="$PROJECT_ID" \
      --replication-policy=automatic \
      --data-file=-
  fi

  gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
    --project="$PROJECT_ID" \
    --member="serviceAccount:${CB_RUNNER}" \
    --role="roles/secretmanager.secretAccessor"
done

echo "=== Done! Now you can submit builds as the service account: ==="
echo ""
echo "  gcloud auth activate-service-account --key-file=secrets/project-b882ddad-b8b1-4a5c-908-09dc8ce802b8.json"
echo ""
echo "  gcloud builds submit \\"
echo "    --project=${PROJECT_ID} \\"
echo "    --config=cloudbuild.yaml \\"
echo "    --substitutions='_DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN}' \\"
echo "    ."
