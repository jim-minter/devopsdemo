#!/bin/bash -ex

if [ -z $OS_AUTH_URL ] || [ -z $VERSION ] || [ -z $PREFIX ]; then
  echo "error: must set OpenStack credentials and inputs"
  exit 1
fi

FUSEVERSION=${VERSION//-/.}

get_ips() {
  eval $(utils/wait-stack.py ci)
  eval $(utils/wait-stack.py dns)
  eval $(utils/wait-stack.py openshift)
  eval $(utils/wait-stack.py $PREFIX-database)
  eval $(utils/wait-stack.py $PREFIX-fabric)
}

prepare_fabric() {
  TMPDIR=$(mktemp -d)

  pushd $TMPDIR
  git clone -b 1.0 http://admin:admin@$ROOT_IP:8181/git/fabric
  cd fabric
  git branch $FUSEVERSION
  git checkout $FUSEVERSION
  popd

  cp -a ../application/profiles/* $TMPDIR/fabric/fabric/profiles
  for FILE in $TMPDIR/fabric/fabric/profiles/ticketmonster/*/io.fabric8.agent.properties
  do
    sed -i -e "s/0.1-SNAPSHOT/$VERSION/g" $FILE
  done
  cat >$TMPDIR/fabric/fabric/profiles/ticketmonster/rest.profile/database.properties <<EOF
serverName = $DATABASE_IP
portNumber = 5432
databaseName = ticketmonster
user = admin
password = password
EOF
  cat >$TMPDIR/fabric/fabric/profiles/ticketmonster/emailroute.profile/email.properties <<EOF
smtp.email.server = 10.4.122.10
EOF

  pushd $TMPDIR
  cd fabric
  git add -A
  git commit -am ticketmonster
  git push --set-upstream origin $FUSEVERSION
  popd

  rm -rf $TMPDIR
}

get_ips
prepare_fabric
