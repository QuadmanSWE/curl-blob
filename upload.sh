#!/bin/sh
set -e
# Arguments
STORAGE_ACCOUNT_NAME=${STORAGE_ACCOUNT_NAME:-$1}
STORAGE_ACCOUNT_KEY=${STORAGE_ACCOUNT_KEY:-$2}
STORAGE_CONTAINER=${STORAGE_CONTAINER:-$3}
BLOB_PATH=${BLOB_PATH:-$4}
FILE_PATH=${FILE_PATH:-$5}
CHUNK_SIZE=${CHUNK_SIZE:-$6}
# Construct the URL
URL="https://${STORAGE_ACCOUNT_NAME}.blob.core.windows.net/${STORAGE_CONTAINER}/${BLOB_PATH}"
# Generate the headers
DATE_VALUE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
STORAGE_SERVICE_VERSION="2019-12-12"

# Construct the CanonicalizedResource
CANONICALIZED_RESOURCE="/${STORAGE_ACCOUNT_NAME}/${STORAGE_CONTAINER}/${BLOB_PATH}"

# Signing key
decoded_hex_key="$(echo -n $STORAGE_ACCOUNT_KEY | base64 -d -w0 | xxd -p -c256)"

# Size of the file
BLOB_LENGTH=$(wc -c <$FILE_PATH)
# Figures out if CHUNK_SIZE is null in which case we always to a single blob upload
if [ -z "$CHUNK_SIZE" ]; then
    CHUNK_SIZE=$BLOB_LENGTH
fi
echo "Blob length: $BLOB_LENGTH"
echo "Chunk size: $CHUNK_SIZE"
#If the file fits in one chunk, upload the file as a single blob
#Else start an empty append blob and upload the file in chunks
if [ $BLOB_LENGTH -le $CHUNK_SIZE ]; then
    BLOB_TYPE="BlockBlob"
    echo "Uploading as a single blob since blob length [$BLOB_LENGTH] is less than or equal to chunk size [$CHUNK_SIZE]"
    # Construct the CanonicalizedHeaders
    CANONICALIZED_HEADERS="x-ms-blob-type:${BLOB_TYPE}\nx-ms-date:${DATE_VALUE}\nx-ms-version:${STORAGE_SERVICE_VERSION}"

    # Generate the signature
    STRING_TO_SIGN="PUT\n\n\n${BLOB_LENGTH}\n\n\n\n\n\n\n\n\n${CANONICALIZED_HEADERS}\n${CANONICALIZED_RESOURCE}"
    SIGNATURE=$(printf "$STRING_TO_SIGN" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)
    AUTHORIZATION_HEADER="SharedKey ${STORAGE_ACCOUNT_NAME}:${SIGNATURE}"

    # Upload the file
    curl -X PUT -T "${FILE_PATH}" -H "x-ms-blob-type: ${BLOB_TYPE}" -H "x-ms-date: ${DATE_VALUE}" -H "x-ms-version: ${STORAGE_SERVICE_VERSION}" -H "Authorization: ${AUTHORIZATION_HEADER}" ${URL}

    # Terminate
    exit 0
else
    CONTENT_TYPE="application/octet-stream"
    LAST_CHUNK_SIZE=$(($BLOB_LENGTH % $CHUNK_SIZE))
    NUMBER_OF_WHOLE_CHUNKS=$(($BLOB_LENGTH / $CHUNK_SIZE))
    BLOB_TYPE="AppendBlob"
    echo "Uploading in [$NUMBER_OF_WHOLE_CHUNKS] whole chunks since blob length [$BLOB_LENGTH] is greater than chunk size [$CHUNK_SIZE]"
    if [ $LAST_CHUNK_SIZE -gt 0 ]; then
        echo "Followed by one last chunk of size [$LAST_CHUNK_SIZE]"
    fi
    CANONICALIZED_HEADERS="x-ms-blob-type:${BLOB_TYPE}\nx-ms-date:${DATE_VALUE}\nx-ms-version:${STORAGE_SERVICE_VERSION}"
    STRING_TO_SIGN="PUT\n\n\n\n\n${CONTENT_TYPE}\n\n\n\n\n\n\n${CANONICALIZED_HEADERS}\n${CANONICALIZED_RESOURCE}"
    SIGNATURE=$(printf "$STRING_TO_SIGN" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)
    AUTHORIZATION_HEADER="SharedKey ${STORAGE_ACCOUNT_NAME}:${SIGNATURE}"
    # Create an empty append blob
    curl -m 2 -X PUT -H "Content-Type: ${CONTENT_TYPE}" -H "Content-Length: 0" -H "x-ms-blob-type: ${BLOB_TYPE}" -H "x-ms-date: ${DATE_VALUE}" -H "x-ms-version: ${STORAGE_SERVICE_VERSION}" -H "Authorization: ${AUTHORIZATION_HEADER}" ${URL}
fi

# Upload the file in chunks
OFFSET=0
CHUNK_NUMBER=0
URL="${URL}?comp=appendblock"
echo "Starting Chunk Upload"
# while there are still whole chunks to upload, append them
while [ $(($OFFSET + $CHUNK_SIZE)) -le $BLOB_LENGTH ]; do
    CANONICALIZED_HEADERS="x-ms-blob-condition-appendpos:${OFFSET}\nx-ms-blob-condition-maxsize:${BLOB_LENGTH}\nx-ms-date:${DATE_VALUE}\nx-ms-version:${STORAGE_SERVICE_VERSION}"
    STRING_TO_SIGN="PUT\n\n\n${CHUNK_SIZE}\n\n${CONTENT_TYPE}\n\n\n\n\n\n\n${CANONICALIZED_HEADERS}\n${CANONICALIZED_RESOURCE}\ncomp:appendblock"
    SIGNATURE=$(printf "$STRING_TO_SIGN" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)
    AUTHORIZATION_HEADER="SharedKey ${STORAGE_ACCOUNT_NAME}:${SIGNATURE}"
    echo "[$CHUNK_NUMBER] Uploading [$CHUNK_SIZE] bytes at offset [$OFFSET]"
    dd if=$FILE_PATH bs=$CHUNK_SIZE count=1 skip=$CHUNK_NUMBER 2>/dev/null |
        curl -m 2 -X PUT --data-binary @- \
            -H "Content-Type: ${CONTENT_TYPE}" \
            -H "Content-Length: $CHUNK_SIZE" \
            -H "x-ms-blob-condition-maxsize: ${BLOB_LENGTH}" \
            -H "x-ms-blob-condition-appendpos: ${OFFSET}" \
            -H "x-ms-date: ${DATE_VALUE}" \
            -H "x-ms-version: ${STORAGE_SERVICE_VERSION}" \
            -H "Authorization: ${AUTHORIZATION_HEADER}" \
            "${URL}"
    OFFSET=$(($OFFSET + $CHUNK_SIZE))
    CHUNK_NUMBER=$(($CHUNK_NUMBER + 1))
done

# Upload the last chunk if it is non-zero
if [ $LAST_CHUNK_SIZE -gt 0 ]; then
    echo "Last chunk is [$LAST_CHUNK_SIZE] bytes at offset [$OFFSET]"
    CANONICALIZED_HEADERS="x-ms-blob-condition-appendpos:${OFFSET}\nx-ms-blob-condition-maxsize:${BLOB_LENGTH}\nx-ms-date:${DATE_VALUE}\nx-ms-version:${STORAGE_SERVICE_VERSION}"
    STRING_TO_SIGN="PUT\n\n\n${LAST_CHUNK_SIZE}\n\n${CONTENT_TYPE}\n\n\n\n\n\n\n${CANONICALIZED_HEADERS}\n${CANONICALIZED_RESOURCE}\ncomp:appendblock"
    SIGNATURE=$(printf "$STRING_TO_SIGN" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)
    AUTHORIZATION_HEADER="SharedKey ${STORAGE_ACCOUNT_NAME}:${SIGNATURE}"
    dd if=$FILE_PATH bs=$CHUNK_SIZE count=1 skip=$CHUNK_NUMBER 2>/dev/null |
        curl -m 2 -X PUT --data-binary @- \
            -H "Content-Type: ${CONTENT_TYPE}" \
            -H "Content-Length: $LAST_CHUNK_SIZE" \
            -H "x-ms-blob-condition-maxsize: ${BLOB_LENGTH}" \
            -H "x-ms-blob-condition-appendpos: ${OFFSET}" \
            -H "x-ms-date: ${DATE_VALUE}" \
            -H "x-ms-version: ${STORAGE_SERVICE_VERSION}" \
            -H "Authorization: ${AUTHORIZATION_HEADER}" \
            "${URL}"
else
    echo "Last chunk is zero bytes, nothing to upload."
fi
