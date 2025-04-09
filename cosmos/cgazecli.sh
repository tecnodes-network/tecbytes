#!/bin/bash
# cosmogaze.sh - @tecnodes - cosmosgaze_v0.0.2
# G.B irretation 08.12.2023

# Repeat every case
repeat_every=""

# set disk usage notify limit
disk_usage_notify_limit=3

# set block signing notify limit
block_signing_notify_limit=3

#set the siging tatios
ratio_green_above=74
ratio_yellow_above=50
ratio_red_below=50

# Function to install jq on Ubuntu
install_dependencies() {
    # Check if jq is installed
    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is not installed. Installing..."

        # Check if sudo is available
        if command -v sudo >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y jq

            # Check if installation was successful
            if command -v jq >/dev/null 2>&1; then
                echo "jq has been installed successfully."
            else
                echo "Failed to install jq. Please install it manually."
                exit 1
            fi
        else
            echo "sudo is not available. Please run this script with sudo privileges or install jq manually."
            exit 1
        fi
    fi
    
}

# Call the function to install jq
install_dependencies



# Check if the first argument is provided and is a number 
# if [[ $1 =~ ^[0-9]+$ ]]; then
#     repeat_every=$1
# fi

load_snapshot() {
    echo "Hello World from load_snapshot function"
}
show_help() {
    printf "\n┌──────────────────────────────────────────────────────────────────────────────────────────────────┐\n"
    printf   "│                                            Help Info                                             │\n"
    printf   "├──────────────────────────────────────────────────────────────────────────────────────────────────┤\n"    
    printf   "│ Usage: ./cgazecli.sh [options]                                                                     │\n"
    printf   "│ Options:                                                                                         │\n"
    printf   "│     repeat_every=<seconds|1s|1h>    Set the interval in seconds for repeating the script.        │\n"
    printf   "│     load_snapshot                   Execute the load_snapshot function.                          │\n"
    printf   "│     help                            Display this help message and exit.                          │\n"
    printf   "╰──────────────────────────────────────────────────────────────────────────────────────────────────╯\n"
}



# command line argument as repeat_every=10
for arg in "$@"; do
    case $arg in
        repeat_every=*)
        repeat_every="${arg#*=}"
        echo "$repeat_every"
        # if [[ $repeat_value =~ ^[0-9]+$ ]]; then
        #     repeat_every=$repeat_value
        # else
        #     echo "Error: repeat_every must be an integer."
        #     repeat_every=0
        # fi
        ;;
        load_snapshot)
        load_snapshot
        exit 0 # exit in case of load snap!
        ;;
        help)
        show_help
        exit 0
        #shift  # Remove current arg
        ;;
    esac
done

# Configuration file path
CONFIG_FILE="file.cfg"

# Function to check if config file exists or create it with default values
initialize_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Creating $CONFIG_FILE with default values."
        echo "rpc_url=https://rpc.atomone.tecnodes.network" > "$CONFIG_FILE"
        echo "blocks_to_scan=50" >> "$CONFIG_FILE"
        echo "validator_address=$(get_default_validator_address)" >> "$CONFIG_FILE"
        #echo "repeat_every=0" >> "$CONFIG_FILE" # later should remove this value
        echo "discord=https://discordapp.com/api/webhooks/1173210512159416351/LiU-VuvpXNCrWNY7m_yAN49QTBgWSHD5M9dTrAIsTwIROPBhWyXjIKxiu4nQmRGqIFvz" >> "$CONFIG_FILE"
        echo "chainhome=~/.atomone" >> "$CONFIG_FILE"
        echo "discord_userid=720577711235399701" >> "$CONFIG_FILE"
    else
        echo "Starting... $CONFIG_FILE Loaded!."
    fi
}

# Function to send notification to Discord
discord_notify() {
    case "$2" in
        "disk_usage_notify_limit")
            if [[ $disk_usage_notify_limit -gt 0 ]];then
                disk_usage_notify_limit=$((disk_usage_notify_limit-1))
            else
                return
            fi
            ;;
        "block_signing_notify_limit")
            if [[ $block_signing_notify_limit -gt 0 ]];then
                block_signing_notify_limit=$((block_signing_notify_limit-1))
            else
                return
            fi
            ;;
        *)
            echo "Unsupported color"  # Handle unsupported color argument
            ;;
    esac
    local message="Hello <@$discord_userid>, $1"
    local webhook_url="$discord"  # Use the webhook URL from file.cfg
    # Send the message using curl
    curl -X POST -H "Content-Type: application/json" -d "{\"content\":\"$message\"}" "$webhook_url"
}

# Function to fetch the default validator address
get_default_validator_address() {
    curl -s "$rpc_url/status" | jq -r '.result.validator_info.address'
}

# Function to read configuration from file.cfg
read_config() {
    source "$CONFIG_FILE"
}

# Function to pint text in colors
color_print(){
    green_color="\e[32m"  # Green color escape code
    yellow_color="\e[33m"  # Yellow color escape code
    red_color="\e[31m"  # Red color escape code
    white_color="\e[37m"  # White color escape code
    no_color="\e[0m"  # Reset color escape code

    case "$1" in
        red)
            echo -e "${red_color}$2${no_color}"  # Print second argument in red color
            ;;
        green)
            echo -e "${green_color}$2${no_color}"  # Print second argument in green color
            ;;
        yellow)
            echo -e "${yellow_color}$2${no_color}"  # Print second argument in yellow color
            ;;
        white)
            echo -e "${white_color}$2${no_color}"  # Print second argument in white color
            ;;
        *)
            echo "Unsupported color"  # Handle unsupported color argument
            ;;
    esac
}


# Function to fetch block signing information
fetch_block_signing_info() {
    printf "\n┌──────────────────────────────────────────────────────────────────────────────────────────────────┐\n"
    printf   "│                                          Signing Info                                            │\n"
    printf   "├──────────────────────────────────────────────────────────────────────────────────────────────────┤\n"
    # Determine the validator addresses to scan
    if [[ -z "$validator_address" ]]; then
        # No validator addresses in config, fetch the default
        validator_address=$(get_default_validator_address)
    fi
    IFS=',' read -ra validator_addresses <<< "$validator_address"

    # Get the latest block height
    latest_block=$(curl -s "$rpc_url/status" | jq -r .result.sync_info.latest_block_height)

    # Calculate the start and end block heights
    start_block=$((latest_block - blocks_to_scan))
    end_block=$latest_block

    # Initialize counters
    total_blocks=0
    total_signed=0
    total_missed=0
    
    # Loop through block heights
    for ((block_height = start_block; block_height < end_block; block_height++)); do
        # Fetch block data
        block_data=$(curl -s "$rpc_url/block?height=$block_height")

        # Extract validator addresses from block data and split them into an array
        validator_addresses_in_block=($(echo "$block_data" | jq -r '.result.block.last_commit.signatures[].validator_address'))
        
        # Loop through validator addresses
        for address in "${validator_addresses[@]}"; do
            signed=false

            # Check if the validator address is in the block's validator list
            for validator_address_in_block in "${validator_addresses_in_block[@]}"; do
                if [[ "$address" == "$validator_address_in_block" ]]; then
                    signed=true
                    break
                fi
            done

            # Update counters based on whether the validator signed or missed the block
            if $signed; then
                ((total_signed++))
            else
                ((total_missed++))
            fi
        done

        ((total_blocks++))

        # Print the "Calculating" message with carriage return to overwrite the line
        
        printf   "\r│ Scanning Blocks... [%d/%d]                                                                       │" "$total_blocks" "$((end_block - start_block))"
        # printf "\rScanning Blocks... [%d/%d]" "$total_blocks" "$((end_block - start_block))"
    done

    echo # Print a newline for separation

    # Calculate ratios and display results
    for address in "${validator_addresses[@]}"; do
        signed_count=0
        missed_count=0

        for ((block_height = start_block; block_height < end_block; block_height++)); do
            block_data=$(curl -s "$rpc_url/block?height=$block_height")
            validator_addresses_in_block=($(echo "$block_data" | jq -r '.result.block.last_commit.signatures[].validator_address'))

            signed=false

            for validator_address_in_block in "${validator_addresses_in_block[@]}"; do
                if [[ "$address" == "$validator_address_in_block" ]]; then
                    signed=true
                    break
                fi
            done

            if $signed; then
                ((signed_count++))
            else
                ((missed_count++))
            fi
        done

        ratio=$((signed_count * 100 / (signed_count + missed_count)))

        
        if [ $ratio -gt $ratio_green_above ];then
            #ratio greater than 74 then print in green color
            ratio_message=$(color_print "green" "Validator Address: $address - Signed: $signed_count, Missed: $missed_count, Ratio: $ratio%")
        elif [ $ratio -gt $ratio_yellow_above ];then
            #ratio greater than 50 then print in yellow color
            color_print "yellow" "Validator Address: $address - Signed: $signed_count\e[0m, Missed: $missed_count, Ratio: $ratio%"
        elif [ $ratio -le $ratio_red_below ];then
            #ratio less than and equal to 50 then print in red color
            color_print "red" "Validator Address: $address - Signed: $signed_count, Missed: $missed_count, Ratio: $ratio%"
            discord_notify "Validator Address: $address - Signed: $signed_count, Missed: $missed_count, Ratio: $ratio%" "block_signing_notify_limit"
        fi
      
        printf   "│ %-50s │\n" "$ratio_message"
        
    done

    # echo "Start Block: $start_block | End Block: $end_block"
    printf   "│ %-96s │\n" "Start Block: $start_block | End Block: $end_block"
    printf "╰──────────────────────────────────────────────────────────────────────────────────────────────────╯\n"
}

# Function to display current CPU usage
get_cpu_usage() {
    # local cpu_usage=$(cat <(grep 'cpu ' /proc/stat) <(sleep 1 && grep 'cpu ' /proc/stat) | awk -v RS="" '{print ($13-$2+$15-$4)*100/($13-$2+$15-$4+$16-$5)}')
    local cpu_usage=$(cat <(grep 'cpu ' /proc/stat) <(sleep 1 && grep 'cpu ' /proc/stat) | awk -v RS="" '{printf "%.0f", ($13-$2+$15-$4)*100/($13-$2+$15-$4+$16-$5)}')
    echo "$cpu_usage"
}

# Function to display current RAM usage
get_ram_usage() {
    local ram_usage=$(free -m | awk '/Mem/ {print $3}')
    echo "$ram_usage"
}

# Function to display current disk usage
get_percentage_disk_usage() {
    local disk_usage=$(df -h / | awk '/\// {print $5}' | sed s/%// )
    echo "$disk_usage"
}

# Function to display current Chain Disk usage
get_chaindisk_usage() {
    local disk_usage_gb=$(du -s $chainhome | awk '{printf "%.2f", $1 / 1048576}')
    echo "$disk_usage_gb"
}



#TO sys_info function
sys_info(){
printf "\n┌──────────────────────────────────────────────────────────────────────────────────────────────────┐\n"
printf "│                                       System Information                   %s│\n" "$(general_info)"
    local cpu_usage=$(get_cpu_usage)
    local ram_usage=$(get_ram_usage)
    local disk_usage=$(get_percentage_disk_usage)
    local chaindisk_usage=$(get_chaindisk_usage)

    
    
    # local message="system information:\nCurrent CPU Usage: $cpu_usage%\nCurrent RAM Usage: $ram_usage MB\nCurrent Disk Usage: $disk_usage%\nCurrent Disk Usage for Chain Home: $chaindisk_usage GB\n"
    # echo -e $message

printf "├───────────────────┬───────────────────┬────────────────────┬─────────────────────────────────────┤\n"
printf "│     CPU Usage     │     RAM Usage     │     Disk Usage     │             Chain Home Dir          │\n"
printf "├───────────────────┼───────────────────┼────────────────────┼─────────────────────────────────────┤\n"
#if the disk usage is greater equal to 80 % notify
if [[ $disk_usage -ge 80 ]]; then
    discord_notify "Alert! Disk Usage: $disk_usage%" "disk_usage_notify_limit"
    disk_usage=$(color_print 'red' $disk_usage%)
else
    disk_usage=$(color_print 'white' $disk_usage%)

fi

if [[ $cpu_usage -ge 80 ]]; then
    
    cpu_usage=$(color_print 'red' $cpu_usage%)
else
    cpu_usage=$(color_print 'white' $cpu_usage%)
fi

printf "│ %-27s│ %-17s │ %-27s │ %-33s   │\n" "$cpu_usage" "$ram_usage MB" "$disk_usage" "$chaindisk_usage GB"


printf "╰───────────────────┴───────────────────┴────────────────────┴─────────────────────────────────────╯\n"

}

namadac_commands() {
    printf "\n┌──────────────────────────────────────────────────────────────────────────────────────────────────┐\n"
    printf   "│                                           Chain  Info                                            │\n"
    printf   "├──────────────────────────────────────────────────────────────────────────────────────────────────┤\n"
    # namada_epoch=$(namadac epoch --node https://rpc.atomone.tecnodes.network | cut -d":" -f2)
    # echo "current namada epoch: $namada_epoch"
    
    printf   "│ %-39s                                                          │\n" "current Info: "
    printf "╰──────────────────────────────────────────────────────────────────────────────────────────────────╯\n"
}

#get current time zone
get_time_zone(){
    echo "$(date +'%:z')"
}

#get current Unix epoch time in seconds
get_current_time_in_seconds(){
    echo "$(date +%s)"
}

#Function to calculate time difference and print formatted message
calculate_time_difference() {
    local time_diff=$1
    local latest_block_formatted=$2
    
    if [ $time_diff -lt 60 ]; then
        seconds=$((time_diff))
        printf "│ %-96s │\n" "Latest Block Time: $latest_block_formatted ($seconds secs ago)"
    elif [ $time_diff -lt 3600 ]; then
        minutes=$((time_diff / 60))
        printf "│ %-96s │\n" "Latest Block Time: $latest_block_formatted ($minutes mins ago)"
    elif [ $time_diff -lt 86400 ]; then
        hours=$((time_diff / 3600))
        printf "│ %-96s │\n" "Latest Block Time: $latest_block_formatted ($hours hrs ago)"
    else
        days=$((time_diff / 86400))
        printf "│ %-96s │\n" "Latest Block Time: $latest_block_formatted ($days days ago)"
    fi
}


# Function to fetch chain information
chain_info() {
    printf "\n┌──────────────────────────────────────────────────────────────────────────────────────────────────┐\n"
    printf   "│                                           Chain Info                                             │\n"
    printf   "├──────────────────────────────────────────────────────────────────────────────────────────────────┤\n"
    
    # Fetch the latest block height, block time, and chain ID from the RPC URL
    latest_block_height=$(curl -s "$rpc_url/status" | jq -r '.result.sync_info.latest_block_height')
    latest_block_time=$(curl -s "$rpc_url/status" | jq -r '.result.sync_info.latest_block_time')
    #print the latest_block_height
    printf "│ %-96s │\n" "Latest Block Height: $latest_block_height"
    # Convert the latest block time to a Unix timestamp based on the time zone
    time_zone=$(get_time_zone)
    latest_block_timestamp=$(date +"%s" -d "$latest_block_time $time_zone")

    # Calculate the difference between the latest block timestamp and the current timestamp
    current_time=$(get_current_time_in_seconds)
    time_diff=$((current_time - latest_block_timestamp))

   
    # Format the latest block time as DD.MM.YYYY HH:MM:SS 
    latest_block_formatted=$(date -d "$latest_block_time" +"%d.%m.%Y %H:%M:%S")
    

    # Function to calculate time difference and print formatted message
    calculate_time_difference $time_diff "$latest_block_formatted"
 
    


    # Check if the latest block time is more than 5 minutes ago
    current_time=$(get_current_time_in_seconds)
    if [ $((current_time - latest_block_timestamp)) -gt 300 ]; then
        # Calculate the time difference in seconds
        time_difference=$((current_tim- latest_block_timestamp))
        # Convert the time difference into a human-readable format
        minutes=$((time_difference / 60))
        #if  0- 60 YELLOW ABOVE 60 SECONDS RED
        if [ $minutes -ge 0 ] && [ $minutes -lt 60 ]; then
            printf   "│ %-105s │\n" "$(color_print "yellow" "Warning: latest block timestamp is more than $minutes minutes old.")"
        elif [ $minutes -ge 60 ]; then
            printf   "│ %-105s │\n" "$(color_print "red" "Warning: latest block timestamp is more than $minutes minutes old.")"
        fi

    fi

    #print the network
    network_value=$(curl -s "$rpc_url/status" | jq -r '.result.node_info.network')
    printf "│ %-96s │\n" "Network: $network_value"
    printf "╰──────────────────────────────────────────────────────────────────────────────────────────────────╯\n"
}

general_info(){    
    current_datetime=$(date +"%dth %b %Y %H:%M:%S")
    echo "$current_datetime"
}

check_rpc_url() {
    if curl --output /dev/null --silent --head --fail "$rpc_url"; then
        #echo "RPC URL is accessible."
        return 0  # Success
    else
        echo "RPC URL is not accessible. Some features will be disabled."
        return 1  # Failure
    fi
}


# Main function
main() {
    initialize_config    

    while true; do
        
        read_config
        sleep 3
        clear        
        sys_info
        namadac_commands
        if check_rpc_url; then
            chain_info
            fetch_block_signing_info
            
        fi
        
        
        if [ ! -z "$repeat_every" ]; then

            echo "sleeping for $repeat_every ..."
            sleep $repeat_every
            clear
            
        else
            break  # Exit the loop if no repetition is needed
        fi        

    done
}

# Execute the main function
main

# next to do
# repeat_every as argument - done
# chain_info, & sys info on console
# discord notify, only when needed
# comparison from other public rpc

