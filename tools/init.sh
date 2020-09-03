DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
echo "alias tlbb=\"/bin/bash ${DIR}/run.sh\"" >> ~/.bashrc
source ~/.bashrc