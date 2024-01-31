#!/usr/bin/env bash

set -eu

KEYSTORE_FILENAME=$KEYSTORE_FILENAME
KEYSTORE_CREDENTIALS_FILENAME=$KEYSTORE_CREDENTIALS_FILENAME
VALIDITY_IN_DAYS=$VALIDITY_IN_DAYS
DEFAULT_TRUSTSTORE_FILENAME=$DEFAULT_TRUSTSTORE_FILENAME
TRUSTSTORE_CREDENTIALS_FILENAME=$TRUSTSTORE_CREDENTIALS_FILENAME
TRUSTSTORE_WORKING_DIRECTORY=$TRUSTSTORE_WORKING_DIRECTORY
KEYSTORE_WORKING_DIRECTORY=$KEYSTORE_WORKING_DIRECTORY
CA_CERT_FILE=$CA_CERT_FILE
CA_KEY_FILE=$CA_KEY_FILE
KEYSTORE_SIGN_REQUEST=$KEYSTORE_SIGN_REQUEST
KEYSTORE_SIGN_REQUEST_SRL=$KEYSTORE_SIGN_REQUEST_SRL
KEYSTORE_SIGNED_CERT=$KEYSTORE_SIGNED_CERT
CN=$CN


COUNTRY=$COUNTRY
STATE=$STATE
OU=$ORGANIZATION_UNIT
LOCATION=$CITY
PASS=$PASSWORD

if [ -n "$KEYSTORE_FILENAME" ]; then
  KEYSTORE_FILENAME="$KEYSTORE_FILENAME"
else
  KEYSTORE_FILENAME="kafka.keystore.jks"
fi

if [ -n "$KEYSTORE_CREDENTIALS_FILENAME" ]; then
  KEYSTORE_CREDENTIALS_FILENAME="$KEYSTORE_CREDENTIALS_FILENAME"
else
  KEYSTORE_CREDENTIALS_FILENAME="kafka_keystore_creds"
fi

if [ -n "$VALIDITY_IN_DAYS" ]; then
  VALIDITY_IN_DAYS="$VALIDITY_IN_DAYS"
else
  VALIDITY_IN_DAYS=3650
fi

if [ -n "$DEFAULT_TRUSTSTORE_FILENAME" ]; then
  DEFAULT_TRUSTSTORE_FILENAME="$DEFAULT_TRUSTSTORE_FILENAME"
else
  DEFAULT_TRUSTSTORE_FILENAME="kafka.truststore.jks"
fi

if [ -n "$TRUSTSTORE_CREDENTIALS_FILENAME" ]; then
  TRUSTSTORE_CREDENTIALS_FILENAME="$TRUSTSTORE_CREDENTIALS_FILENAME"
else
  TRUSTSTORE_CREDENTIALS_FILENAME="kafka_trusttore_creds"
fi

if [ -n "$TRUSTSTORE_WORKING_DIRECTORY" ]; then
  TRUSTSTORE_WORKING_DIRECTORY="$TRUSTSTORE_WORKING_DIRECTORY"
else
  TRUSTSTORE_WORKING_DIRECTORY="truststore"
fi

if [ -n "$KEYSTORE_WORKING_DIRECTORY" ]; then
  KEYSTORE_WORKING_DIRECTORY="$KEYSTORE_WORKING_DIRECTORY"
else
  KEYSTORE_WORKING_DIRECTORY="keystore"
fi

if [ -n "$CA_CERT_FILE" ]; then
  CA_CERT_FILE="$CA_CERT_FILE"
else
  CA_CERT_FILE="ca-cert"
fi

if [ -n "$CA_KEY_FILE" ]; then
  CA_KEY_FILE="$CA_KEY_FILE"
else
  CA_KEY_FILE="ca-key"
fi


if [ -n "$KEYSTORE_SIGN_REQUEST" ]; then
  KEYSTORE_SIGN_REQUEST="$KEYSTORE_SIGN_REQUEST"
else
  KEYSTORE_SIGN_REQUEST="cert-file"
fi

if [ -n "$KEYSTORE_SIGN_REQUEST_SRL" ]; then
  KEYSTORE_SIGN_REQUEST_SRL="$KEYSTORE_SIGN_REQUEST_SRL"
else
  KEYSTORE_SIGN_REQUEST_SRL=$CA_CERT_FILE".srl"
fi

if [ -n "$KEYSTORE_SIGNED_CERT" ]; then
  KEYSTORE_SIGNED_CERT="$KEYSTORE_SIGNED_CERT"
else
  KEYSTORE_SIGNED_CERT="cert-signed"
fi

if [ -n "$CN" ]; then
  CN="$CN"
else
  CN=`hostname -f`
fi

function file_exists_and_exit() {
  echo "'$1' cannot exist. Move or delete it before"
  echo "re-running this script."
  exit 1
}

if [ -z "$COUNTRY" ]; then
  file_exists_and_exit COUNTRY
fi

if [ -z "$STATE" ]; then
  file_exists_and_exit STATE
fi

if [ -z "$ORGANIZATION_UNIT" ]; then
  file_exists_and_exit ORGANIZATION_UNIT
fi

if [ -z "$CITY" ]; then
  file_exists_and_exit CITY
fi

if [ -z "$PASSWORD" ]; then
  file_exists_and_exit PASSWORD
fi


trust_store_file=""
trust_store_private_key_file=""

  mkdir $TRUSTSTORE_WORKING_DIRECTORY
  echo
  echo "OK, we'll generate a trust store and associated private key."
  echo
  echo "First, the private key."
  echo

  openssl req -new -x509 -keyout $TRUSTSTORE_WORKING_DIRECTORY/$CA_KEY_FILE \
    -out $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE -days $VALIDITY_IN_DAYS -nodes \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCATION/O=$OU/CN=$CN"

  trust_store_private_key_file="$TRUSTSTORE_WORKING_DIRECTORY/$CA_KEY_FILE"

  echo
  echo "Two files were created:"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/$CA_KEY_FILE -- the private key used later to"
  echo "   sign certificates"
  echo " - $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE -- the certificate that will be"
  echo "   stored in the trust store in a moment and serve as the certificate"
  echo "   authority (CA). Once this certificate has been stored in the trust"
  echo "   store, it will be deleted. It can be retrieved from the trust store via:"
  echo "   $ keytool -keystore <trust-store-file> -export -alias CARoot -rfc"

  echo
  echo "Now the trust store will be generated from the certificate."
  echo

  keytool -keystore $TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME \
    -alias CARoot -import -file $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE \
    -noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" -keypass $PASS -storepass $PASS

  trust_store_file="$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME"

  echo
  echo "$TRUSTSTORE_WORKING_DIRECTORY/$DEFAULT_TRUSTSTORE_FILENAME was created."

  # don't need the cert because it's in the trust store.
  rm $TRUSTSTORE_WORKING_DIRECTORY/$CA_CERT_FILE

echo
echo "Continuing with:"
echo " - trust store file:        $trust_store_file"
echo " - trust store private key: $trust_store_private_key_file"

mkdir $KEYSTORE_WORKING_DIRECTORY

echo
echo "Now, a keystore will be generated. Each broker and logical client needs its own"
echo "keystore. This script will create only one keystore. Run this script multiple"
echo "times for multiple keystores."
echo
echo "     NOTE: currently in Kafka, the Common Name (CN) does not need to be the FQDN of"
echo "           this host. However, at some point, this may change. As such, make the CN"
echo "           the FQDN. Some operating systems call the CN prompt 'first / last name'"

# To learn more about CNs and FQDNs, read:
# https://docs.oracle.com/javase/7/docs/api/javax/net/ssl/X509ExtendedTrustManager.html

keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME \
  -alias localhost -validity $VALIDITY_IN_DAYS -genkey -keyalg RSA \
   -noprompt -dname "C=$COUNTRY, ST=$STATE, L=$LOCATION, O=$OU, CN=$CN" -keypass $PASS -storepass $PASS

echo
echo "'$KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME' now contains a key pair and a"
echo "self-signed certificate. Again, this keystore can only be used for one broker or"
echo "one logical client. Other brokers or clients need to generate their own keystores."

echo
echo "Fetching the certificate from the trust store and storing in $CA_CERT_FILE."
echo

keytool -keystore $trust_store_file -export -alias CARoot -rfc -file $CA_CERT_FILE -keypass $PASS -storepass $PASS

echo
echo "Now a certificate signing request will be made to the keystore."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost \
  -certreq -file $KEYSTORE_SIGN_REQUEST -keypass $PASS -storepass $PASS

echo
echo "Now the trust store's private key (CA) will sign the keystore's certificate."
echo
openssl x509 -req -CA $CA_CERT_FILE -CAkey $trust_store_private_key_file \
  -in $KEYSTORE_SIGN_REQUEST -out $KEYSTORE_SIGNED_CERT \
  -days $VALIDITY_IN_DAYS -CAcreateserial
# creates $KEYSTORE_SIGN_REQUEST_SRL which is never used or needed.

echo
echo "Now the CA will be imported into the keystore."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias CARoot \
  -import -file $CA_CERT_FILE -keypass $PASS -storepass $PASS -noprompt
rm $CA_CERT_FILE # delete the trust store cert because it's stored in the trust store.

echo
echo "Now the keystore's signed certificate will be imported back into the keystore."
echo
keytool -keystore $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_FILENAME -alias localhost -import \
  -file $KEYSTORE_SIGNED_CERT -keypass $PASS -storepass $PASS

echo $PASS > $KEYSTORE_WORKING_DIRECTORY/$KEYSTORE_CREDENTIALS_FILENAME
echo $PASS > $TRUSTSTORE_WORKING_DIRECTORY/$TRUSTSTORE_CREDENTIALS_FILENAME

echo
echo "All done!"
echo
echo "Deleting intermediate files. They are:"
echo " - '$KEYSTORE_SIGN_REQUEST_SRL': CA serial number"
echo " - '$KEYSTORE_SIGN_REQUEST': the keystore's certificate signing request"
echo "   (that was fulfilled)"
echo " - '$KEYSTORE_SIGNED_CERT': the keystore's certificate, signed by the CA, and stored back"
echo "    into the keystore"

  rm $KEYSTORE_SIGN_REQUEST_SRL
  rm $KEYSTORE_SIGN_REQUEST
  rm $KEYSTORE_SIGNED_CERT

