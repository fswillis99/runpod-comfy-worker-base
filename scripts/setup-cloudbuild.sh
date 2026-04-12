#!/usr/bin/env bash
# Run this once from your local machine to set up Google Cloud Build.
# Prerequisites: gcloud CLI installed and authenticated (or use the service account key).
#
# Usage:
#   gcloud auth activate-service-account --key-file=secrets/project-b882ddad-b8b1-4a5c-908-09dc8ce802b8.json
#   bash scripts/setup-cloudbuild.sh

set -euo pipefail

PROJECT_ID="project-b882ddad-b8b1-4a5c-908"
REPO_OWNER="fswillis99"
REPO_NAME="runpod-comfy-worker-base"
DOCKERHUB_USERNAME="fswillis99"
DOCKERHUB_TOKEN="dckr_pat_ZjpcY6x4viPh2FgN_Vw_dLLAe2k"

gcloud config set project "$PROJECT_ID"

echo "Enabling required APIs..."
gcloud services enable cloudbuild.googleapis.com secretmanager.googleapis.com

echo "Storing Docker Hub credentials in Secret Manager..."
echo -n "$DOCKERHUB_USERNAME" | gcloud secrets create dockerhub-username \
  --replication-policy=automatic --data-file=- 2>/dev/null || \
  echo -n "$DOCKERHUB_USERNAME" | gcloud secrets versions add dockerhub-username --data-file=-

echo -n "$DOCKERHUB_TOKEN" | gcloud secrets create dockerhub-token \
  --replication-policy=automatic --data-file=- 2>/dev/null || \
  echo -n "$DOCKERHUB_TOKEN" | gcloud secrets versions add dockerhub-token --data-file=-

echo "Granting Cloud Build service account access to secrets..."
CB_SA="$(gcloud projects describe "$PROJECT_ID" \
  --format='value(projectNumber)')@cloudbuild.gserviceaccount.com"
for SECRET in dockerhub-username dockerhub-token; do
  gcloud secrets add-iam-policy-binding "$SECRET" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/secretmanager.secretAccessor"
done

echo "Creating Cloud Build trigger (watches master branch)..."
gcloud builds triggers create github \
  --name="build-and-push-docker" \
  --repo-name="$REPO_NAME" \
  --repo-owner="$REPO_OWNER" \
  --branch-pattern="^master$" \
  --build-config="cloudbuild.yaml" \
  --region="global" 2>/dev/null || echo "Trigger may already exist."

echo ""
echo "Done. To trigger a manual build:"
echo "  gcloud builds submit --config=cloudbuild.yaml --project=$PROJECT_ID ."
