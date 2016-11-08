echo 'Installing NodeJs'

#brew install node

modules=(
	eslint
	grunt
	nodemon
	create-react-app
	surge
)

for module in ${modules[*]}; do
	script="$script $module"
done;

echo "executing npm install -g$script" 

npm install -g $script

