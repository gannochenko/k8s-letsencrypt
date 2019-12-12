#!/bin/bash

if [[ -z $EMAIL || -z $DOMAINS || -z $SECRET ]]; then
	echo "EMAIL, DOMAINS, SECRET environment variables are mandatory"
	env
	exit 1
fi

SERVICEACCOUNT_MP=/var/run/secrets/kubernetes.io/serviceaccount
NAMESPACE=$(cat ${SERVICEACCOUNT_MP}/namespace)
K8S_API=https://kubernetes.default/api/v1/namespaces/${NAMESPACE}
TOKEN=$(cat ${SERVICEACCOUNT_MP}/token)
CERTPATH=/etc/letsencrypt/live/$(echo ${DOMAINS} | cut -f1 -d',')
DRY_RUN=

SECRET_PATCH_TEMPLATE=/templates/secret-patch.json
SECRET_POST_TEMPLATE=/templates/secret-post.json
INGRESS_PATCH_TEMPLATE=/templates/ingress-patch.json

echo "Using:"
echo "namespace = ${NAMESPACE}"

cd $HOME

if [[ $RENEWAL ]]; then
    echo "Renewing the certificate"

    # todo
else
    echo "Obtaining the certificate"

    # starting a dummy service to pass ACME-challenges, run certbot against it, then shut down the server
    python3 -m http.server 80 &
    sleep 5
    PID=$!
    certbot certonly --webroot -w $HOME -n --agree-tos --email ${EMAIL} --no-self-upgrade -d ${DOMAINS}
    kill $PID

    if [[ ! -f /etc/resolv.conf ]]; then
        echo "Was not able to get a certificate, check the certbot output"
        exit 1
    fi

    TLSCERT=$(cat ${CERTPATH}/fullchain.pem | base64 | tr -d '\n')
    TLSKEY=$(cat ${CERTPATH}/privkey.pem | base64 | tr -d '\n')

#    TLSCERT=Zm9v
#    TLSKEY=YmFy

    if [[ ! ${TLSCERT} || ! ${TLSKEY} ]]; then
        echo "Was not able to get a certificate, check the certbot output"
        exit 1
    fi

    # updating the secret
    cat ${SECRET_PATCH_TEMPLATE} | \
        sed "s/NAMESPACE/${NAMESPACE}/" | \
        sed "s/NAME/${SECRET}/" | \
        sed "s/TLSCERT/${TLSCERT}/" | \
        sed "s/TLSKEY/${TLSKEY}/" \
        > /secret-patch.json

    RESPONSE=`curl -v --cacert ${SERVICEACCOUNT_MP}/ca.crt -H "Authorization: Bearer ${TOKEN}" -k -v -XPATCH  -H "Accept: application/json, */*" -H "Content-Type: application/strategic-merge-patch+json" -d @/secret-patch.json ${K8S_API}/secrets/${SECRET}`
#    echo "RESPONSE:";
#    echo ${RESPONSE};
    RESPONSE_CODE=`echo ${RESPONSE} | jq -r '.code'`

#    echo "RESPONSE_CODE:"
#    echo ${RESPONSE_CODE}

    # check the RESPONSE_CODE: create the secret if there is none
    case ${RESPONSE_CODE} in
    404)
        echo "Secret doesn't exist, creating"
        RESP=`curl -v --cacert ${SERVICEACCOUNT_MP}/ca.crt -H "Authorization: Bearer ${TOKEN}" -k -v -XPOST  -H "Accept: application/json, */*" -H "Content-Type: application/json" -d @/secret-patch.json ${K8S_API}/secrets`
        echo $RESP
        ;;
    esac

    # restart the ingress
    ## ?? should we?
fi
