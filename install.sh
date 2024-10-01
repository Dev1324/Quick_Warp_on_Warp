#!/bin/bash

# Define colors for output
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
CYAN=$(tput setaf 6)
RED=$(tput setaf 1)
RESET=$(tput sgr0)

# Function to get values from the API
get_values() {
    local api_output=$(curl -sL "https://api.zeroteam.top/warp?format=sing-box")
    local ipv6=$(echo "$api_output" | grep -oE '"2606:4700:[0-9a-f:]+/128"' | sed 's/"//g')
    local private_key=$(echo "$api_output" | grep -oE '"private_key":"[0-9a-zA-Z\/+]+=+"' | sed 's/"private_key":"//; s/"//')
    local public_key=$(echo "$api_output" | grep -oE '"peer_public_key":"[0-9a-zA-Z\/+]+=+"' | sed 's/"peer_public_key":"//; s/"//')
    local reserved=$(echo "$api_output" | grep -oE '"reserved":\[[0-9]+(,[0-9]+){2}\]' | sed 's/"reserved"://; s/\[//; s/\]//')
    
    echo "$ipv6@$private_key@$public_key@$reserved"
}

# Detect CPU architecture
case "$(uname -m)" in
    x86_64 | x64 | amd64 ) cpu=amd64 ;;
    i386 | i686 ) cpu=386 ;;
    armv8 | armv8l | arm64 | aarch64 ) cpu=arm64 ;;
    armv7l ) cpu=arm ;;
    * ) echo "The current architecture is $(uname -m), temporarily not supported"; exit 1 ;;
esac

# Download Warp endpoint file based on architecture
cfwarpIP(){
    echo "Downloading Warp endpoint file based on your CPU architecture..."
    if [[ -n $cpu ]]; then
        curl -L -o warpendpoint -# --retry 2 "https://raw.githubusercontent.com/azavaxhuman/Quick_Warp_on_Warp/main/cpu/$cpu"
    fi
}

# Generate random IPv4 addresses
endipv4(){
    n=0
    iplist=100
    while [ $n -lt $iplist ]; do
        temp[$n]=$(echo 162.159.192.$(($RANDOM%256)))
        n=$((n+1))
        temp[$n]=$(echo 162.159.193.$(($RANDOM%256)))
        n=$((n+1))
        temp[$n]=$(echo 162.159.195.$(($RANDOM%256)))
        n=$((n+1))
        temp[$n]=$(echo 188.114.96.$(($RANDOM%256)))
        n=$((n+1))
        temp[$n]=$(echo 188.114.97.$(($RANDOM%256)))
        n=$((n+1))
        temp[$n]=$(echo 188.114.98.$(($RANDOM%256)))
        n=$((n+1))
        temp[$n]=$(echo 188.114.99.$(($RANDOM%256)))
        n=$((n+1))
    done
}

# Save unique IPs to file and run endpoint
endipresult(){
    temp_var=$1
    echo "${temp[@]}" | tr ' ' '\n' | sort -u > ip.txt
    ulimit -n 102400
    chmod +x warpendpoint
    ./warpendpoint
    clear
    echo "${GREEN}Successfully generated IPv4 endip list${RESET}"
    echo "${GREEN}Successfully created result.csv file${RESET}"
    echo "${CYAN}Now processing result.csv...${RESET}"
    
    if [ ! -f "./result.csv" ]; then
        echo "${RED}Error: result.csv file not found!${RESET}"
        touch result.csv
    fi
    
    process_result_csv $temp_var
    rm -rf ip.txt warpendpoint result.csv
    exit
}

# Process result.csv file and generate JSON configuration
process_result_csv() {
    count_conf=$1
    
    values=$(get_values)
    w_ip=$(echo "$values" | cut -d'@' -f1)
    w_pv=$(echo "$values" | cut -d'@' -f2)
    w_pb=$(echo "$values" | cut -d'@' -f3)
    w_res=$(echo "$values" | cut -d'@' -f4)

    # Get the number of lines in result.csv
    num_lines=$(wc -l < ./result.csv)
    
    if ! [[ "$num_lines" =~ ^[0-9]+$ ]]; then
        echo "${RED}Error: Invalid number of lines in result.csv!${RESET}"
        exit 1
    fi
    
    echo ""
    echo "We have ${num_lines} IPs."
    
    if [ "$count_conf" -lt "$num_lines" ]; then
        num_lines=$count_conf
    elif [ "$count_conf" -gt "$num_lines" ]; then
        echo "Warning: The number of IPs found is less than the number you requested!"
        num_lines=$count_conf
    fi

    # Loop through result.csv and create configurations
    for ((i=2; i<=num_lines; i++)); do
        line=$(sed -n "${i}p" ./result.csv)
        endpoint=$(echo "$line" | awk -F',' '{print $1}')
        ip=$(echo "$endpoint" | awk -F':' '{print $1}')
        port=$(echo "$endpoint" | awk -F':' '{print $2}')
        
        new_json='{
          "type": "wireguard",
          "tag": "Warp-IR'"$i"'",
          "server": "'"$ip"'",
          "server_port": '"$port"',
          "local_address": ["172.16.0.2/32", "'"$w_ip"'"],
          "private_key": "'"$w_pv"'",
          "peer_public_key": "'"$w_pb"'",
          "reserved": ['$w_res'],
          "mtu": 1280,
          "fake_packets": "5-10"
        }'
        
        temp_json+="$new_json"
        
        if [ $i -lt $num_lines ]; then
            temp_json+=","
        fi
    done

    full_json='{
      "outbounds": 
      [
        '"$temp_json"'
      ]
    }'
    
    echo "$full_json" > output.json
    echo ""
    echo "${GREEN}Upload Files to Get Link${RESET}"
    echo "------------------------------------------------------------"
    echo ""
    echo "Your link:"
    curl https://bashupload.com/ -T output.json | sed -e 's#wget#Your Link#' -e 's#https://bashupload.com/\(.*\)#https://bashupload.com/\1?download=1#'
    echo "------------------------------------------------------------"
    echo ""
    mv output.json output_$(date +"%Y%m%d_%H%M%S").json
}

# Display menu
menu(){
    clear
    echo "--------------- DDS-WOW -----------------------------"
    echo ""
    echo "Welcome to DDS-WOW(WARP on Warp)"
    echo "1. Automatic scanning and execution (Android / Linux)"
    echo "2. Import custom IPs with result.csv file (Windows)"
    read -r -p "Please choose an option: " option
    
    if [ "$option" = "1" ]; then
        echo "How many configurations do you need?"
        read -r -p "Number of required configurations (suggested 5 or 10):  " number_of_configs
        cfwarpIP
        endipv4
        endipresult $number_of_configs
    elif [ "$option" = "2" ]; then
        read -r -p "Number of required configurations (suggested 5 or 10):  " number_of_configs
        process_result_csv $number_of_configs
    else
        echo "${RED}Invalid option${RESET}"
    fi
}

# Run the menu
menu
