#!/bin/bash

sudo yum install httpd -y
sudo systemctl start httpd

exec > >( sudo tee /var/www/html/script-logs |logger -t vault_data ) 2>&1
echo ------  BEGIN -----
date '+%Y-%m-%d %H:%M:%S'

echo 
echo ---------------
echo "Setting up variables for root"
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN=root


echo 
echo ---------------
echo "Login with root token"
vault login $VAULT_TOKEN

echo 
echo ---------------
echo "Creating a new secret path"
vault kv put secret/details name=vishnu


if [[ $? == 0 ]]; then
echo 
echo ---------------
echo "Creating the policy file"
cat > /tmp/my-policy.hcl <<- "EOF"
path "secret/data/details" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
else exit 1
fi

echo 
echo ---------------
if [ -f /tmp/my-policy.hcl ]
  then echo "Creating policy from the policy file"
	  vault policy write my-policy /tmp/my-policy.hcl
  else echo "File policy file doesn't exist"; exit 1
fi

echo "creating token for a user"
TOKEN=`vault token create -policy=my-policy | grep -w 'token' | awk '{print $2}'`
echo 

echo 
echo ---------------
echo "adding a new user - vishnu"
sudo useradd vishnu
echo 

echo 
echo ---------------
echo "putting key value objects in the secret: vault kv put secret/details name=vishnu age=30"
sudo su - vishnu -c "export VAULT_ADDR='http://127.0.0.1:8200'; export VAULT_TOKEN=$TOKEN; vault login $TOKEN; \
                    vault kv put secret/details name=vishnu age=30"

echo 
echo ---------------
echo 
echo "retrieving value of a key from secret: vault kv get -field=name secret/details"
sudo su - vishnu -c "export VAULT_ADDR='http://127.0.0.1:8200'; export VAULT_TOKEN=$TOKEN; vault login $TOKEN; echo "";\
                    echo -ne 'retrieved key value from vault:- '; vault kv get -field=name secret/details"
