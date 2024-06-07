#!/bin/bash

PRG="$0"
# Need this for relative symlinks.
while [ -h "$PRG" ] ; do
    ls=$(ls -ld "$PRG")
    link=$(expr "$ls" : '.*-> \(.*\)$')
    if expr "$link" : '/.*' > /dev/null; then
        PRG="$link"
    else
        PRG=$(dirname "$PRG")"/$link"
    fi
done
SAVED=$(pwd)
cd "$(dirname "$PRG")/.." >&-
APP_HOME=$(pwd -P)
cd "$SAVED" >&-

if [ "$#" -ne 1 ]; then
    echo "Usage: $PRG <name of the certs>"
    exit 1
fi

CERT_NAME=$1
CERT_DIR="${APP_HOME}/certs"
CERT_KEY="${CERT_DIR}/${CERT_NAME}-ca-key.pem.txt"
CERT_PEM="${CERT_DIR}/${CERT_NAME}-ca-certificate.pem.txt"
KEYSTORE="${CERT_DIR}/${CERT_NAME}.jks"
STOREPASS="changeit"

if [ -f "$KEYSTORE" ]; then
    exit 0
fi

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA key and certificate
openssl req -new -x509 -keyout "$CERT_KEY" -out "$CERT_PEM" -days 365 -passout pass:$STOREPASS <<EOF
US
CA
CA Test
The Testing CA
Tester CA
localhost
ca@foo.bar
EOF

# Generate keystore and self-signed certificate
keytool -genkeypair -alias testing -keystore "$KEYSTORE" -keyalg RSA -keysize 2048 -sigalg SHA256withRSA -validity 365 -storepass $STOREPASS -dname "CN=localhost, OU=Test OU, O=Test OU Name, L=Testing City, ST=Unit Test, C=US"

# List the contents of the keystore
keytool -list -v -keystore "$KEYSTORE" -storepass $STOREPASS

# Generate the Signing Request
keytool -keystore "$KEYSTORE" -certreq -alias testing -keyalg RSA -file "${CERT_NAME}.csr" -storepass $STOREPASS

# Sign the certificate request
openssl x509 -req -in "${CERT_NAME}.csr" -CA "$CERT_PEM" -CAkey "$CERT_KEY" -out "${CERT_NAME}.cer" -days 365 -CAcreateserial -passin pass:$STOREPASS

# Import the CA certificate
keytool -import -keystore "$KEYSTORE" -file "$CERT_PEM" -alias testtrustca -storepass $STOREPASS <<EOF
y
EOF

# Import the signed certificate
keytool -import -keystore "$KEYSTORE" -file "${CERT_NAME}.cer" -alias testing -storepass $STOREPASS

# List the contents of the keystore again
keytool -list -v -keystore "$KEYSTORE" -storepass $STOREPASS

cd "$SAVED" >&-
