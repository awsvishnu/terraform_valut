#!/bin/bash

echo "Setting up variables for root"
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN=root

vault login VAULT_TOKEN

#Creating the policy file 
echo "Creating a new secret path"
vault kv put secret/details name=vishnu

if [[ $? == 0 ]]; then
cat > /tmp/my-policy.hcl <<- "EOF"
path "secret/data/details" {
  capabilities = ["create", "update", "read", "update", "delete", "list"]
}
EOF
else exit 1
fi

if [ -f /tmp/my-policy.hcl ]
  then vault policy write my-policy /tmp/my-policy.hcl
  else echo "File policy file doesn't exist"; exit 1
fi

echo "creating token for a user"
TOKEN=`vault token create -policy=my-policy | grep -w 'token' | awk '{print $2}'`
echo 
echo "Derived token is $TOKEN"

echo "adding a new user - vishnu"
sudo useradd vishnu
echo 

echo  "Installing httpd"
sudo yum install httpd -y
sudo systemct start httpd 

echo "putting key value objects name and age in the secret" | tee -a /var/www/html/index.html
sudo su - vishnu -c "export VAULT_ADDR='http://127.0.0.1:8200'; export VAULT_TOKEN=$TOKEN; vault login $TOKEN; \
                    vault kv put secret/details name=vishnu age=30 | tee -a /var/www/html/index.html"

echo "retrieving value of a key from secret"
sudo su - vishnu -c "export VAULT_ADDR='http://127.0.0.1:8200'; export VAULT_TOKEN=$TOKEN; vault login $TOKEN; \
                    echo -ne 'retrieved value of name key from vault is  '; vault kv get -field=name secret/details >> /var/www/html/index.html"


