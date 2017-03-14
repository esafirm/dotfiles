publichash(){

	# check arguments
    if [ $# -eq 0 ]; 
    then 
        echo "No arguments specified. Use public hash [DOMAIN] [PORT]"
        return 1
    fi

	openssl s_client -connect $1:$2 | openssl x509 -pubkey -noout | openssl rsa -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64

}

publichash_sha1(){

	# check arguments
    if [ $# -eq 0 ]; 
    then 
        echo "No arguments specified. Use public hash [DOMAIN] [PORT]"
        return 1
    fi

	openssl s_client -connect $1:$2 | openssl x509 -pubkey -noout | openssl rsa -pubin -outform der | openssl dgst -sha1 -binary | openssl enc -base64

}
