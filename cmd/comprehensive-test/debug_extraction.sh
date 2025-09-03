#!/bin/bash
# Debug what HAProxy extracts from AWS V4 header

AUTH_HEADER="AWS4-HMAC-SHA256 Credential=5HQZO7EDOM4XBNO642GQ/20250903/us-east-1/s3/aws4_request, SignedHeaders=content-length;content-md5;host;x-amz-content-sha256;x-amz-date, Signature=a8cae3afd"

echo "Original header:"
echo "$AUTH_HEADER"
echo ""

echo "Split by '=' and get parts:"
IFS='=' read -ra PARTS <<< "$AUTH_HEADER"
for i in "${!PARTS[@]}"; do
    echo "Part $i: ${PARTS[i]}"
done
echo ""

echo "word(2,'=') would be: ${PARTS[1]}"
echo ""

# Get first part before '/' from that
SECOND_PART="${PARTS[1]}"
IFS='/' read -ra SLASH_PARTS <<< "$SECOND_PART"
echo "word(1,'/') from that would be: ${SLASH_PARTS[0]}"
