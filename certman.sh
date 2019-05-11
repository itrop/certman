#!/bin/bash
# Purpose: Check SSL Certificate Expiration Date + additional functionality 
# Author: itrop@op.pl 
# Tested: 
#   GNU bash, version 4.2.46(2)-release (x86_64-redhat-linux-gnu)
#   CentOS Linux release 7.6.1810 (Core) 

# ---------------------------------------------------------------------------
# Capture signals using the trap
# ---------------------------------------------------------------------------
# trap '' SIGINT   # CTRL+C
trap ''  SIGQUIT
trap '' SIGTSTP  # CTRL+Z

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
readonly CSR=server.csr
readonly KEY=server.key
readonly PUBKEY=server.pub
readonly CRT=server.crt
readonly SERVER=www.github.com
readonly PORT=443

# ---------------------------------------------------------------------------
# Checking if required bins are installed
# ---------------------------------------------------------------------------
is_installed(){
    rc=$?;
    bin_name=$1
    if [[ $rc != 0 ]]; then
        echo "Script '$0' requires the '$bin_name' that seems to be not installed. Exiting..."
        exit $rc;
    fi
}

OPENSSL=$(which openssl)
is_installed "openssl"

DATE=$(which date)
is_installed "date"

FILE=$(which file)
is_installed "file" 

# ---------------------------------------------------------------------------
# Helper functions 
# ---------------------------------------------------------------------------
# display message and pause 
pause(){
    local k
    echo "$@"
    read -p "Press [Enter] key to continue..." k
}

read_server(){
    read -p "Provide server name (default: $SERVER): " server
    if [[ -z ${server//} ]]; then
        server=$SERVER
    fi
}

read_port(){
    read -p "Provide port number (default: $PORT): " port
    if [[ -z ${port//} ]]; then
        port=$PORT
    fi
}

# generic function reading file name
read_filename(){
    filename=$1
    local def_file=$2
    local prompt=$3
    
    [[ -n ${filename//} ]] && local DEF=$filename || local DEF=$def_file
    read -p "$prompt (default: $DEF): " filename
    if [[ -z ${filename//} ]]; then
        filename=$DEF    
    fi
}

read_csr_filename(){
    read_filename "$csr" "$CSR" "Provide CSR file name"
    csr=$filename
}

read_key_filename(){
    read_filename "$key" "$KEY" "Provide KEY file name"
    key=$filename
}

read_crt_filename(){
    read_filename "$crt" "$CRT" "Provide certificate file name"
    crt=$filename
}

read_pubkey_filename(){
    read_filename "$pubkey" "$PUBKEY" "Provide public key file name"
    pubkey=$filename
}

# checks only header and footer
check_type(){
    local file=$1

    local crl=('-----BEGIN X509 CRL-----' '-----END X509 CRL-----')
    local crt=('-----BEGIN CERTIFICATE-----' '-----END CERTIFICATE-----')
    local csr=('-----BEGIN CERTIFICATE REQUEST-----' '-----END CERTIFICATE REQUEST-----')
    local new_csr=('-----BEGIN NEW CERTIFICATE REQUEST-----' '-----END NEW CERTIFICATE REQUEST-----')
    local pem=('-----BEGIN RSA PRIVATE KEY-----' '-----END RSA PRIVATE KEY-----')
    local pkcs7=('-----BEGIN PKCS7-----' '-----END PKCS7-----')
    local prv_key=('-----BEGIN PRIVATE KEY-----' '-----END PRIVATE KEY-----')
    local pub_key=('-----BEGIN PUBLIC KEY-----' '-----END PUBLIC KEY-----')

    # local is_prv_key=$(grep -l "${prv_key[0]}" $file | xargs grep -l "${prv_key[1]}")
    # [ -n is_prv_key ] && echo "private key detected" 
}

display_file(){
    if [ -f "$1" ]; then
        echo -n $(ls -al "$1") 
        echo -n " <--- "
        $FILE -b "$1"

        # todo: check_type "$1"
    fi
}

show_files(){
    echo "---------------------------------------"
    echo "Generated files:"
    for par in "$@"; do
        display_file "$par"
    done
    echo "---------------------------------------"
}

remove_files(){
    echo "---------------------------------------"
    echo "Files to remove:"
    for par in "$@"; do
         [ -f "$par" ] && rm -i "$par"
    done 
    echo "---------------------------------------"
}

# ---------------------------------------------------------------------------
# Cert related functions 
# ---------------------------------------------------------------------------
cert_exp_servers(){
    local input="certman.chk"
    while IFS= read -r line
    do
        local server=${line%:*} # remove suffix starting with ":"
        local port=${line#*:}   # remove prefix ending in ":"
        echo -n "For $line --> "
        cert_exp $server $port
    done < "$input"
}

cert_exp(){
    local server=$1
    local port=$2
    local debug=$3

    [ -n "$debug" ] && echo "Checking certificate for $server:$port"
    local cert_dates=$(echo | $OPENSSL s_client -servername "$server" -connect "$server:$port" 2>/dev/null | $OPENSSL x509 -noout -dates)
    # [ -n "$debug" ] && echo cert_dates=$cert_dates
	
    local notBefore_keyin=${cert_dates%notAfter*}  # remove suffix starting with "notAfter"
    local notBefore=${notBefore_keyin#*=}
    [ -n "$debug" ] && echo -n "not vaild before= $notBefore"

    local notAfter=${cert_dates#*notAfter=}  # remove prefix ending in "notAfter"
    [ -n "$debug" ] && echo "not valid after = $notAfter"

    # echo $(DATE -d "$notAfter" +"%b %d %H:%M:%S %Y %Z")
    [ -n "$debug" ] && echo "current date is = $($DATE +"%b %d %H:%M:%S %Y %Z")"
    local days=$(( ($($DATE -d "$notAfter" +"%s") - $($DATE  +"%s"))/(60*60*24) ))
    echo "Days left: $days"
}

gen_key_with_csr(){
    local key="$1"
    local csr="$2"
    $OPENSSL req -out "$csr" -new -newkey rsa:2048 -nodes -keyout "$key"
}

gen_key_with_cert(){
    local key="$1"
    local crt="$2"
    $OPENSSL req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout "$key" -out "$crt"
}

gen_csr_for_key(){
    local key="$1"
    local crt="$2"
    $OPENSSL req -key "$key" -new -out "$crt"
}

gen_csr_for_key_and_cert(){
    local key="$1"
    local crt="$2"
    local csr="$3"
    $OPENSSL x509 -in "$crt" -signkey "$key" -x509toreq -out "$csr" 
}

gen_crt_for_key(){
    local key="$1"
    local crt="$2"
    $OPENSSL req -key "$key" -new -x509 -days 365 -out "$crt"
}

gen_crt_for_key_and_csr(){
    local key="$1"
    local csr="$2"
    local crt="$3"
    $OPENSSL x509 -signkey "$key" -in "$csr" -req -days 365 -out "$crt"
}

gen_pubkey_from_key(){
    local key="$1"
    local pubkey="$2"
    $OPENSSL rsa -in "$key" -pubout -out "$pubkey" 
}

check_key(){
    local key="$1"
    $OPENSSL rsa -in "$key" -check -noout 
}

view_csr(){
    local csr="$1"
    $OPENSSL req -in "$csr" -text -verify -noout
}

view_crt(){
    local crt="$1"
    $OPENSSL x509 -text -noout -in "$crt"
}

# ---------------------------------------------------------------------------
# Only check and exit - do not enter while loop 
# ---------------------------------------------------------------------------
if [ "$1" == "-c" ]; then
    cert_exp_servers
    exit
fi

# ---------------------------------------------------------------------------
# Main while loop 
# ---------------------------------------------------------------------------
while :
do
    clear
    echo "----------------------------------------------------------------------------"
    echo "	                      M A I N - M E N U"
    echo "----------------------------------------------------------------------------"
    echo "1. How many days left to certificate expiration for one server"
    echo "2. How many days left to certificate expiration for many servers"
    echo
    echo "3. Generate a new private key and certificate signing request (CSR)"
    echo "4. Generate a new private key and self-signed certificate (CRT)"
    echo "5. Generate a CSR for an existing private key"
    echo "6. Generate a CSR from an existing certificate and private key"
    echo "7. Generate a self-signed certificate from an existing private key"
    echo "8. Generate a self-signed certificate from an existing private key and CSR"
    echo "9. Generate a public key based on a private one"
    echo
    echo "a. Verify a private key"
    echo "b. View CSR entries"
    echo "c. View certificate entries"
    echo
    echo "h. Launch shell: $SHELL"
    echo "l. Show files in current directory"
    echo "s. Show lastly generated files"
    echo "r. Remove lastly generated files"
    echo "q. Quit"
    echo "----------------------------------------------------------------------------"
    read -r -p "Make your choice [ 1-9 | a-z ] and press [Enter]: " choice
    
    case $choice in
        1)  read_server; read_port;
            cert_exp $server $port 1; pause;;

        2)  cert_exp_servers; pause;;

        3)  read_key_filename; read_csr_filename;
            gen_key_with_csr "$key" "$csr"; 
            show_files "$key" "$csr"; pause;;

        4)  read_key_filename; read_crt_filename;
            gen_key_with_cert "$key" "$crt"; 
            show_files "$key" "$crt"; pause;;

        5)  read_key_filename; read_csr_filename;
            gen_csr_for_key "$key" "$csr"; 
            show_files "$csr"; pause;;

        6)  read_key_filename; read_crt_filename; read_csr_filename;
            gen_csr_for_key_and_cert "$key" "$crt" "$csr"
            show_files "$csr"; pause;;

        7)  read_key_filename; read_crt_filename;
            gen_crt_for_key "$key" "$crt";
            show_files "$crt"; pause;;

        8)  read_key_filename; read_csr_filename; read_crt_filename;
            gen_crt_for_key_and_csr "$key" "$csr" "$crt";
            show_files "$crt"; pause;;

        9)  read_key_filename; read_pubkey_filename;
            gen_pubkey_from_key "$key" "$pubkey";
            show_files "$pubkey"; pause;;

        a)  read_key_filename;
            check_key "$key"; pause;;

        b)  read_csr_filename;
            view_csr "$csr"; pause;;

        c)  read_crt_filename;
            view_crt "$crt"; pause;;
        
        h)  echo "You are about to launch default shell. Type 'exit' to go back to $0 script."; 
            $SHELL;;

        l)  echo -n "PWD= "; pwd; ls -Ft; pause;;
        s)  show_files "$key" "$pubkey" "$csr" "$crt"; pause;;
        r)  remove_files "$key" "$pubkey" "$csr" "$crt"; pause;;
        q)  break;;
        *)  pause "Unrecognized command. Please try again."
    esac
done
