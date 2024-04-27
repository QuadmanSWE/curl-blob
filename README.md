# curl-blob

Demonstrates how to upload a file from a linux OS to an azure blob storage container at a prefix.

## Arguments

### Using a storage account key

1. storage account name - These account names are globally unique. They get turned into a globally unique URL.

2. Storage account Key - This is a secret which allows anyone with it to access the storage account in full.

3. storage container - These are unique within each storage account

3. Blob path - Where in the storage container you want the blob to exist.

4. FilePath - The path to the file to be uploaded.

5. (optional) ChunkSize - The amount of data to upload to azure in one go. Useful if you either have a tiny amount of RAM available or some behemoth file you need to shovel (or both :D)

### Using a SAS token

Works exactly the same way but you replace the third argument with SAS Token:

2. SAS Token - This is a secret which allows anyone with it to access the storage account in the manner that the tokens allow, you can limit to an exact location if you want to match the blob path.

## Example execution from sh

### Upload file using account key
``` sh
sh upload.sh \
  your-storage-account-name \
  your-storage-account-key \
  your-storage-container \
  your-blob-path \
  hello.txt
```

### Upload file using SAS token 

``` sh
sh upload_sas.sh \
  your-storage-account-name \
  'your-sas-token' \
  your-storage-container \
  your-blob-path \
  hello.txt
```

### Upload file using account key in chunks
``` sh
sh upload.sh \
  your-storage-account-name \
  your-storage-account-key \
  your-storage-container \
  your-blob-path \
  hello2860.txt \
  715
```

### Upload file using SAS token in chunks

``` sh
sh upload_sas.sh \
  your-storage-account-name \
  'your-sas-token' \
  your-storage-container \
  your-blob-path \
  hello2860.txt \
  1024
```

## Example execution with container

### Build docker image first
```
docker build -t curl-blob:latest .
```

### Or pull my prebuilt image

```
docker pull dsoderlund/curl-blob:latest
docker tag dsoderlund/curl-blob:latest curl-blob:latest
```

### Upload file using account key

``` sh
docker run \
  -e STORAGE_ACCOUNT_NAME=your-storage-account-name \
  -e STORAGE_ACCOUNT_KEY=your-storage-account-key \
  -e STORAGE_CONTAINER=your-storage-container \
  -e BLOB_PATH=your-blob-path \
  -e FILE_PATH=/file \
  -v /path/to/file/hello.txt:/file \
  curl-blob:latest
```

### Upload file using SAS token 

``` sh
docker run \
  -e STORAGE_ACCOUNT_NAME=your-storage-account-name \
  -e SAS_TOKEN='your-sas-token' \
  -e STORAGE_CONTAINER=your-storage-container \
  -e BLOB_PATH=your-blob-path \
  -e FILE_PATH=/file \
  -v /path/to/file/hello.txt:/file \
  curl-blob:latest
```

### Upload file using account key in chunks

``` sh
docker run \
  -e STORAGE_ACCOUNT_NAME=your-storage-account-name \
  -e STORAGE_ACCOUNT_KEY=your-storage-account-key \
  -e STORAGE_CONTAINER=your-storage-container \
  -e BLOB_PATH=your-blob-path \
  -e FILE_PATH=/file \
  -e CHUNK_SIZE=666 \
  -v /path/to/file/hello2860.txt:/file \
  curl-blob:latest
```

### Upload file using SAS token in chunks

``` sh
docker run \
  -e STORAGE_ACCOUNT_NAME=your-storage-account-name \
  -e SAS_TOKEN='your-sas-token' \
  -e STORAGE_CONTAINER=your-storage-container \
  -e BLOB_PATH=your-blob-path \
  -e FILE_PATH=/file \
  -e CHUNK_SIZE=572 \
  -v /path/to/file/hello2860.txt:/file \
  curl-blob:latest
```

### Ad hoc from powershell in windows

``` PowerShell
$stgAcc = 'mystorageacc'
$stgKey = Read-Host -MaskInput -Prompt 'Enter the storage account key'
$container = 'curl-blob'
$blobpath = 'somedir/upload/hello.txt'
$localFilePath = 'hello.txt'
$filePath = Get-Item $localFilePath | Select-Object -ExpandProperty FullName

docker run -v "${filePath}:/file" curl-blob:latest $stgAcc $stgKey $container $blobpath /file
```

### Powershell in chunks

``` PowerShell
$stgAcc = 'mystorageacc'
$stgKey = Read-Host -MaskInput -Prompt 'Enter the storage account key'
$container = 'curl-blob'
$blobpath = 'somedir/upload/hello2860.txt'
$localFilePath = 'hello2860.txt'
$filePath = Get-Item $localFilePath | Select-Object -ExpandProperty FullName
$chunksize=1234

docker run -v "${filePath}:/file" curl-blob:latest $stgAcc $stgKey $container $blobpath /file $chunksize
```

### Docker compose example

``` yaml
version: '3'
services:
  upload-file:
    image: curl-blob:latest
    environment:
      - STORAGE_ACCOUNT_NAME=your-storage-account-name
      - STORAGE_ACCOUNT_KEY=your-storage-account-key
      - STORAGE_CONTAINER=your-storage-container
      - BLOB_PREFIX=your-blob-prefix
      - FILE_PATH=/path/to/file
      - CHUNK_SIZE=1048576
    volumes:
      - /path/to/file:/path/to/file
    restart: "no"
```

### Kubernetes job

``` yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: your-job
spec:
  template:
    spec:
      containers:
      - name: upload-file
        image: curl-blob:latest
        env:
        - name: STORAGE_ACCOUNT_NAME
          value: your-storage-account-name
        - name: STORAGE_ACCOUNT_KEY
          valueFrom:
            secretKeyRef:
              name: your-secret-name
              key: your-secret-key
        - name: STORAGE_CONTAINER
          value: your-storage-container
        - name: BLOB_PREFIX
          value: your-blob-prefix
        - name: FILE_PATH
          value: /path/to/file
        - name: CHUNK_SIZE
          value: 8388608
        volumeMounts:
        - name: your-volume
          mountPath: /path/to/file
      volumes:
      - name: your-volume
        hostPath:
          path: /path/on/host
      restartPolicy: Never
  backoffLimit: 2
```
