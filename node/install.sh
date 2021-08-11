echo 'Installing NodeJs'

## Installing NodeJS
brew install node

modules=(
    yarn
)

for module in ${modules[*]}; do
    script="$script $module"
done;

echo "executing npm install -g $script"

npm install -g $script

