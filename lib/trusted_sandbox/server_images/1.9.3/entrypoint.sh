uid=$1

if [ -z $uid ]; then
  echo "you must provide a uid"
  exit 1
fi

echo "127.0.0.1 $(hostname)" >> /etc/hosts

if [ -n "$USE_QUOTAS" -a "$USE_QUOTAS" != "0" -a "$USE_QUOTAS" != "false" ]; then
  usermod -u $uid sandbox
  chown sandbox /home/sandbox/src
fi

sudo -u sandbox -i bundle exec ruby run.rb