# Simple test using AWS CLI signature (requires aws-cli installed)
# Replace these values with your actual credentials and bucket
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
BUCKET="your-bucket-name"
REGION="us-east-1"
OBJECT_KEY="manage-api-keys"

# # Method 1: Using aws-cli to generate signed URL, then use with curl
# aws s3 presign "s3://${BUCKET}/${OBJECT_KEY}" --expires-in 3600 --region "${REGION}"
# Then use the generated URL with curl -X PUT

# Method 2: Manual curl command (example with hardcoded values)
# You need to calculate the signature using the script above
curl -vvv -X PUT \
  "localhost" \
  -H "Host: localhost" \
  -H "Content-Length: 32" \
  -H "Content-Type: text/plain" \
  -H "X-Amz-Date: 20240904T120000Z" \
  -H "X-Amz-Content-Sha256: b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9" \
  -H "Authorization: AWS4-HMAC-SHA256 Credential=YOUR_ACCESS_KEY/20240904/us-east-1/s3/aws4_request, SignedHeaders=content-length;content-type;host;x-amz-content-sha256;x-amz-date, Signature=CALCULATED_SIGNATURE" \
  -d "Hello, S3! This is a test file."

# Method 3: Quick test with existing file
# Upload a local file to S3 using presigned URL
# echo "Hello, S3! This is a test file." > test-file.txt
# PRESIGNED_URL=$(aws s3 presign "s3://${BUCKET}/${OBJECT_KEY}" --expires-in 3600 --region "${REGION}")
# curl -X PUT "$PRESIGNED_URL" --upload-file test-file.txt

# Method 4: Using awscurl (third-party tool that handles signing)
# Install: pip install awscurl
# awscurl --service s3 -X PUT -d "Hello, S3! This is a test file." "https://your-bucket-name.s3.amazonaws.com/test-file.txt"
