#!/bin/bash

set -euo pipefail

# Input parameters passed to the script
AWS_REGION="us-east-1"   
ACCOUNT_NAME="$1"       
REPO_NAME="$2"          


declare -A ACCOUNT_IDS=(
  ["stage"]="267230788984"
  ["prod"]="896521799855"
)

if [[ -z "${ACCOUNT_IDS[$ACCOUNT_NAME]:-}" ]]; then
  echo "Error: Invalid account name '${ACCOUNT_NAME}'. Allowed values are: ${!ACCOUNT_IDS[@]}" >&2
  exit 1
fi

AWS_ACCOUNT_ID="${ACCOUNT_IDS[$ACCOUNT_NAME]}"

if [[ "$ACCOUNT_NAME" == "prod" ]]; then
  HELM_CHART_PATH="${REPO_NAME}/devops/helm/values-production-main.yaml"
else
  HELM_CHART_PATH="${REPO_NAME}/devops/helm/values-staging-main.yaml"
fi


if [[ ! -f "${HELM_CHART_PATH}" ]]; then
  echo "Error: Helm chart file ${HELM_CHART_PATH} does not exist!" >&2
  exit 1
fi

echo "Running Helm Chart Update Script..."
echo "AWS Region: ${AWS_REGION}"
echo "Account Name: ${ACCOUNT_NAME}"
echo "Repository Name: ${REPO_NAME}"
echo "Helm Chart Path: ${HELM_CHART_PATH}"
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"


LATEST_TAG=$(aws ecr describe-images \
  --repository-name "${REPO_NAME}" \
  --region "${AWS_REGION}" \
  --query 'sort_by(imageDetails, &imagePushedAt)[-1].imageTags[0]' \
  --output text)

if [ -z "$LATEST_TAG" ] || [ "$LATEST_TAG" == "null" ]; then
  echo "Error: No valid tags found for the latest image in ECR." >&2
  exit 1
fi

echo "Latest ECR image tag: ${LATEST_TAG}"


sed -i "s/^  tag: .*/  tag: ${LATEST_TAG}/" "${HELM_CHART_PATH}"


helm lint "$(dirname "${HELM_CHART_PATH}")"

git config user.name "GitHub Actions Bot"
git config user.email "actions@github.com"
git add "${HELM_CHART_PATH}"
git commit -m "Update image tag to ${LATEST_TAG} for account ${ACCOUNT_NAME} and repository ${REPO_NAME}"
git push

echo "Helm Chart Update Script completed successfully."