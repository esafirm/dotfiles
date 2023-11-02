echo 'Installing Javascript related packages…'

modules=(
    node
    pnpm
)

for module in ${modules[*]}; do
    script="$script $module"
done;

echo "executing npm install -g $script"

npm install -g $script

