#!/bin/bash

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   sleep 1
   exit 1
fi


#color codes
GREEN="\033[0;32m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
RESET="\033[0m"
MAGENTA="\033[0;35m"


# just press key to continue
press_key(){
 read -p "Press Enter to continue..."
}


# Define a function to colorize text
colorize() {
    local color="$1"
    local text="$2"
    local style="${3:-normal}"
    
    # Define ANSI color codes
    local black="\033[30m"
    local red="\033[31m"
    local green="\033[32m"
    local yellow="\033[33m"
    local blue="\033[34m"
    local magenta="\033[35m"
    local cyan="\033[36m"
    local white="\033[37m"
    local reset="\033[0m"
    
    # Define ANSI style codes
    local normal="\033[0m"
    local bold="\033[1m"
    local underline="\033[4m"
    # Select color code
    local color_code
    case $color in
        black) color_code=$black ;;
        red) color_code=$red ;;
        green) color_code=$green ;;
        yellow) color_code=$yellow ;;
        blue) color_code=$blue ;;
        magenta) color_code=$magenta ;;
        cyan) color_code=$cyan ;;
        white) color_code=$white ;;
        *) color_code=$reset ;;  # Default case, no color
    esac
    # Select style code
    local style_code
    case $style in
        bold) style_code=$bold ;;
        underline) style_code=$underline ;;
        normal | *) style_code=$normal ;;  # Default case, normal text
    esac

    # Print the colored and styled text
    echo -e "${style_code}${color_code}${text}${reset}"
}


# Function to install unzip if not already installed
install_unzip() {
    if ! command -v unzip &> /dev/null; then
        # Check if the system is using apt package manager
        if command -v apt-get &> /dev/null; then
            echo -e "${RED}unzip is not installed. Installing...${NC}"
            sleep 1
            sudo apt-get update
            sudo apt-get install -y unzip
        else
            echo -e "${RED}Error: Unsupported package manager. Please install unzip manually.${NC}\n"
            read -p "Press any key to continue..."
            exit 1
        fi
    fi
}


install_easytier() {
    # Define the directory and files
    DEST_DIR="/root/easytier"
    FILE1="easytier-core"
    FILE2="easytier-cli"
    URL_X86="https://github.com/EasyTier/EasyTier/releases/download/v1.1.0/easytier-x86_64-unknown-linux-musl-v1.1.0.zip"
    URL_ARM_SOFT="https://github.com/EasyTier/EasyTier/releases/download/v1.1.0/easytier-armv7-unknown-linux-musleabi-v1.1.0.zip"              
    URL_ARM_HARD="https://github.com/EasyTier/EasyTier/releases/download/v1.1.0/easytier-armv7-unknown-linux-musleabihf-v1.1.0.zip"
    
    
    # Check if the directory exists
    if [ -d "$DEST_DIR" ]; then    
        # Check if the files exist
        if [ -f "$DEST_DIR/$FILE1" ] && [ -f "$DEST_DIR/$FILE2" ]; then
            colorize green "EasyMesh Core Installed" bold
            return 0
        fi
    fi
    
    # Detect the system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        URL=$URL_X86
        ZIP_FILE="/root/easytier/easytier-x86_64-unknown-linux-musl-v1.1.0.zip"
    elif [ "$ARCH" = "armv7l" ] || [ "$ARCH" = "aarch64" ]; then
        if [ "$(ldd /bin/ls | grep -c 'armhf')" -eq 1 ]; then
            URL=$URL_ARM_HARD
            ZIP_FILE="/root/easytier/easytier-armv7-unknown-linux-musleabihf-v1.1.0.zip"
        else
            URL=$URL_ARM_SOFT
            ZIP_FILE="/root/easytier/easytier-armv7-unknown-linux-musleabi-v1.1.0.zip"
        fi
    else
        colorize red "Unsupported architecture: $ARCH\n" bold
        return 1
    fi


    colorize yellow "Installing EasyMesh Core...\n" bold
    mkdir -p $DEST_DIR &> /dev/null
    curl -L $URL -o $ZIP_FILE &> /dev/null
    unzip $ZIP_FILE -d $DEST_DIR &> /dev/null
    rm $ZIP_FILE &> /dev/null

    if [ -f "$DEST_DIR/$FILE1" ] && [ -f "$DEST_DIR/$FILE2" ]; then
        colorize green "EasyMesh Core Installed Successfully...\n" bold
        sleep 1
        return 0
    else
        colorize red "Failed to install EasyMesh Core...\n" bold
        return 1
    fi
}



# Call the functions
install_unzip
install_easytier

generate_random_secret() {
    openssl rand -hex 6
}

#Var
EASY_CLIENT='/root/easytier/easytier-cli'
SERVICE_FILE="/etc/systemd/system/easymesh.service"
    
connect_network_pool(){
	clear
	colorize cyan "Connect to the Mesh Network" bold 
	echo ''
	
    read -p "[-] Enter Peer IPv4/IPv6 Addresses (separate multiple addresses by ','): " PEER_ADDRESSES
    
    read -p "[*] Enter Local IPv4 Address (e.g., 10.144.144.1): " IP_ADDRESS
    if [ -z $IP_ADDRESS ]; then
    	colorize red "Null value. aborting..."
    	sleep 2
    	return 1
    fi
    
    read -r -p "[*] Enter Hostname (e.g., Hetnzer): " HOSTNAME
    if [ -z $HOSTNAME ]; then
    	colorize red "Null value. aborting..."
    	sleep 2
    	return 1
    fi
    
    read -p "[-] Enter Tunnel Port (Default 2090): " PORT
    if [ -z $PORT ]; then
    	colorize red "Default port is 2090..."
    	PORT='2090'
    fi
    
	echo ''
    NETWORK_SECRET=$(generate_random_secret)
    colorize cyan "[✓] Generated Network Secret: $NETWORK_SECRET" bold
    while true; do
    read -p "[*] Enter Network Secret (recommend using a strong password): " NETWORK_SECRET
    if [[ -n $NETWORK_SECRET ]]; then
        break
    else
        colorize red "Network secret cannot be empty. Please enter a valid secret.\n"
    fi
	done
	
	

	echo ''
    colorize green "[-] Select Default Protocol:" bold
    echo "1) tcp"
    echo "2) udp"
    echo "3) ws"
    echo "4) wss"
    read -p "[*] Select your desired protocol (e.g., 1 for tcp): " PROTOCOL_CHOICE
	
    case $PROTOCOL_CHOICE in
        1) DEFAULT_PROTOCOL="tcp" ;;
        2) DEFAULT_PROTOCOL="udp" ;;
        3) DEFAULT_PROTOCOL="ws" ;;
        4) DEFAULT_PROTOCOL="wss" ;;
        *) colorize red "Invalid choice. Defaulting to tcp." ; DEFAULT_PROTOCOL="tcp" ;;
    esac
	
	echo ''
	read -p "[-] Enable encryption? (yes/no): " ENCRYPTION_CHOICE
	case $ENCRYPTION_CHOICE in
        [Nn]*)
        	ENCRYPTION_OPTION="--disable-encryption"
        	colorize yellow "Encryption is disabled"
       		 ;;
   		*)
       		ENCRYPTION_OPTION=""
       		colorize yellow "Encryption is enabled"
             ;;
	esac
	
	echo ''

    
    IFS=',' read -ra ADDR_ARRAY <<< "$PEER_ADDRESSES"
    PROCESSED_ADDRESSES=()
    for ADDRESS in "${ADDR_ARRAY[@]}"; do
        ADDRESS=$(echo $ADDRESS | xargs)
        
        if [[ "$ADDRESS" == *:* ]]; then
            if [[ "$ADDRESS" != \[*\] ]]; then
                ADDRESS="[$ADDRESS]"
            fi
        fi
    
        if [ ! -z "$ADDRESS" ]; then
            PROCESSED_ADDRESSES+=("${DEFAULT_PROTOCOL}://${ADDRESS}:${PORT}")
        fi
    done
    
    JOINED_ADDRESSES=$(IFS=' '; echo "${PROCESSED_ADDRESSES[*]}")
    
    if [ ! -z "$JOINED_ADDRESSES" ]; then
        PEER_ADDRESS="--peers ${JOINED_ADDRESSES}"
    fi
    
    LISTENERS="--listeners ${DEFAULT_PROTOCOL}://[::]:${PORT} ${DEFAULT_PROTOCOL}://0.0.0.0:${PORT}"
    
    SERVICE_FILE="/etc/systemd/system/easymesh.service"
    
cat > $SERVICE_FILE <<EOF
[Unit]
Description=EasyMesh Network Service
After=network.target

[Service]
ExecStart=/root/easytier/easytier-core -i $IP_ADDRESS $PEER_ADDRESS --hostname $HOSTNAME --network-secret $NETWORK_SECRET --default-protocol $DEFAULT_PROTOCOL $LISTENERS --multi-thread $ENCRYPTION_OPTION
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start the service
    sudo systemctl daemon-reload &> /dev/null
    sudo systemctl enable easymesh.service &> /dev/null
    sudo systemctl start easymesh.service &> /dev/null

    colorize green "EasyMesh Network Service Started.\n" bold
	press_key
}


display_peers()
{	
	watch -n1 $EASY_CLIENT peer	
}
display_routes(){

	watch -n1 $EASY_CLIENT route	
}

peer_center(){

	watch -n1 $EASY_CLIENT peer-center	
}

restart_easymesh_service() {
	echo ''
	if [[ ! -f $SERVICE_FILE ]]; then
		colorize red "	EasyMesh service does not exists." bold
		sleep 1
		return 1
	fi
    colorize yellow "	Restarting EasyMesh service...\n" bold
    sudo systemctl restart easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        colorize green "	EasyMesh service restarted successfully." bold
    else
        colorize red "	Failed to restart EasyMesh service." bold
    fi
    echo ''
	 read -p "	Press Enter to continue..."
}

remove_easymesh_service() {
	echo ''
	if [[ ! -f $SERVICE_FILE ]]; then
		 colorize red "	EasyMesh service does not exists." bold
		 sleep 1
		 return 1
	fi
    colorize yellow "	Stopping EasyMesh service..." bold
    sudo systemctl stop easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        colorize green "	EasyMesh service stopped successfully.\n"
    else
        colorize red "	Failed to stop EasyMesh service.\n"
        sleep 2
        return 1
    fi

    colorize yellow "	Disabling EasyMesh service..." bold
    sudo systemctl disable easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        colorize green "	EasyMesh service disabled successfully.\n"
    else
        colorize red "	Failed to disable EasyMesh service.\n"
        sleep 2
        return 1
    fi

    colorize yellow "	Removing EasyMesh service..." bold
    sudo rm /etc/systemd/system/easymesh.service &> /dev/null
    if [[ $? -eq 0 ]]; then
        colorize green "	EasyMesh service removed successfully.\n"
    else
        colorize red "	Failed to remove EasyMesh service.\n"
        sleep 2
        return 1
    fi

    colorize yellow "	Reloading systemd daemon..." bold
    sudo systemctl daemon-reload
    if [[ $? -eq 0 ]]; then
        colorize green "	Systemd daemon reloaded successfully.\n"
    else
        colorize red "	Failed to reload systemd daemon.\n"
        sleep 2
        return 1
    fi
    
 read -p "	Press Enter to continue..."
}

show_network_secret() {
	echo ''
    if [[ -f $SERVICE_FILE ]]; then
        NETWORK_SECRET=$(grep -oP '(?<=--network-secret )[^ ]+' $SERVICE_FILE)
        
        if [[ -n $NETWORK_SECRET ]]; then
            colorize cyan "	Network Secret Key: $NETWORK_SECRET" bold
        else
            colorize red "	Network Secret key not found" bold
        fi
    else
        colorize red "	EasyMesh service does not exists." bold
    fi
    echo ''
    read -p "	Press Enter to continue..."
   
    
}

view_service_status() {
	if [[ ! -f $SERVICE_FILE ]]; then
		 colorize red "	EasyMesh service does not exists." bold
		 sleep 1
		 return 1
	fi
	clear
    sudo systemctl status easymesh.service
}

set_watchdog(){
	clear
	view_watchdog_status
	echo ''
	colorize cyan "Select your option:" bold
	colorize green "1) Start Watchdog"
	colorize red "2) Stop Watchdog"
    colorize yellow "3) View Logs"
    colorize reset "4) Back"
    echo ''
    read -p "Enter your choice: " CHOICE
    case $CHOICE in 
    	1) start_watchdog ;;
    	2) stop_watchdog ;;
    	3) view_logs ;;
    	4) return 0;;
    	*) colorize red "Invalid option!" bold && sleep 1 && return 1;;
    esac

}

start_watchdog(){
	clear
	colorize cyan "Important: You can check the status of the service \nand restart it if the latency is higher than a certain limit. \nI recommend to run it only on one server and preferably outside (Kharej) server" bold
	echo ''
	
	read -p "Enter the local IP address to monitor: " IP_ADDRESS
	read -p "Enter the latency threshold in ms (200): " LATENCY_THRESHOLD
	read -p "Enter the time between checks in seconds (8): " CHECK_INTERVAL
	
	rm -f /etc/monitor.sh /etc/monitor.log &> /dev/null
	touch /etc/monitor.sh /etc/monitor.log &> /dev/null
	
cat << EOF | sudo tee /etc/monitor.sh > /dev/null
#!/bin/bash

# Configuration
IP_ADDRESS="$IP_ADDRESS"
LATENCY_THRESHOLD=$LATENCY_THRESHOLD
CHECK_INTERVAL=$CHECK_INTERVAL
SERVICE_NAME="easymesh.service"
LOG_FILE="/etc/monitor.log"

# Function to restart the service
restart_service() {
    local restart_time=\$(date +"%Y-%m-%d %H:%M:%S")
    sudo systemctl restart "\$SERVICE_NAME"
    if [ \$? -eq 0 ]; then
        echo "\$restart_time: Service \$SERVICE_NAME restarted successfully." >> "\$LOG_FILE"
    else
        echo "\$restart_time: Failed to restart service \$SERVICE_NAME." >> "\$LOG_FILE"
    fi
}

# Function to calculate average latency
calculate_average_latency() {
    local latencies=(\$(ping -c 3 -W 2 -i 0.2 "\$IP_ADDRESS" | grep 'time=' | sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p'))
    local total_latency=0
    local count=\${#latencies[@]}

    for latency in "\${latencies[@]}"; do
        total_latency=\$(echo "\$total_latency + \$latency" | bc)
    done

    if [ \$count -gt 0 ]; then
        local average_latency=\$(echo "scale=2; \$total_latency / \$count" | bc)
        echo \$average_latency
    else
        echo 0
    fi
}

# Main monitoring loop
while true; do
    # Calculate average latency
    AVG_LATENCY=\$(calculate_average_latency)
    
    if [ "\$AVG_LATENCY" == "0" ]; then
        echo "\$(date +"%Y-%m-%d %H:%M:%S"): Failed to ping \$IP_ADDRESS. Restarting service..." >> "\$LOG_FILE"
        restart_service
    else
        LATENCY_INT=\${AVG_LATENCY%.*}  # Convert latency to integer for comparison
        if [ "\$LATENCY_INT" -gt "\$LATENCY_THRESHOLD" ]; then
            echo "\$(date +"%Y-%m-%d %H:%M:%S"): Average latency \$AVG_LATENCY ms exceeds threshold of \$LATENCY_THRESHOLD ms. Restarting service..." >> "\$LOG_FILE"
            restart_service
        fi
    fi

    # Wait for the specified interval before checking again
    sleep "\$CHECK_INTERVAL"
done
EOF


echo ''
# Execute the script in the background
    (bash /etc/monitor.sh > /dev/null 2>&1 &)
    if [ $? -eq 0 ]; then
        colorize green "Watchdog started successfully." bold
    else
        colorize red "Failed to start watchdog." bold
    fi
    echo ''
press_key
}

# Function to stop the watchdog
stop_watchdog() {
	echo ''
    PIDS=$(pgrep -f /etc/monitor.sh)
    if [ -n "$PIDS" ]; then
        pkill -f /etc/monitor.sh > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            colorize green "Watchdog stopped successfully." bold
        else
            colorize red "Failed to stop watchdog." bold
        fi
    else
        colorize yellow "Watchdog is not running." bold
    fi
    echo ''
    rm -f /etc/monitor.sh /etc/monitor.log &> /dev/null
    press_key
}

view_watchdog_status(){
    PIDS=$(pgrep -f /etc/monitor.sh)
    if [ -z "$PIDS" ]; then
    	colorize red "	Watchdog is not running" bold
    else
    	colorize green "	Watchdog is running" bold
    fi
    echo "---------------------------------------------"
}
# Function to view logs
view_logs() {
    if [ -f /etc/monitor.log ]; then
        less +G /etc/monitor.log
    else
    	echo ''
        colorize yellow "No logs found.\n" bold
        press_key
    fi
    
}


# Function to add cron-tab job
add_cron_job() {
	echo 

	local service_name="easymesh.service"
	
    # Prompt user to choose a restart time interval
    colorize cyan "Select the restart time interval:" bold
    echo
    echo "1. Every 30th minute"
    echo "2. Every 1 hour"
    echo "3. Every 2 hours"
    echo "4. Every 4 hours"
    echo "5. Every 6 hours"
    echo "6. Every 12 hours"
    echo "7. Every 24 hours"
    echo
    read -p "Enter your choice: " time_choice
    # Validate user input for restart time interval
    case $time_choice in
        1)
            restart_time="*/30 * * * *"
            ;;
        2)
            restart_time="0 * * * *"
            ;;
        3)
            restart_time="0 */2 * * *"
            ;;
        4)
            restart_time="0 */4 * * *"
            ;;
        5)
            restart_time="0 */6 * * *"
            ;;
        6)
            restart_time="0 */12 * * *"
            ;;
        7)
            restart_time="0 0 * * *"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a number between 1 and 7.${NC}\n"
            sleep 2
            return 1
            ;;
    esac


    # remove cronjob created by this script
    delete_cron_job > /dev/null 2>&1
    
    # Path to reset file
    local reset_path="/root/easytier/reset.sh"
    
    #add cron job to kill the running easymesh processes
    cat << EOF > "$reset_path"
#! /bin/bash
pids=\$(pgrep easytier)
sudo kill -9 \$pids
sudo systemctl daemon-reload
sudo systemctl restart $service_name
EOF

    # make it +x
    chmod +x "$reset_path"
    
    # Save existing crontab to a temporary file
    crontab -l > /tmp/crontab.tmp

    # Append the new cron job to the temporary file
    echo "$restart_time $reset_path #$service_name" >> /tmp/crontab.tmp

    # Install the modified crontab from the temporary file
    crontab /tmp/crontab.tmp

    # Remove the temporary file
    rm /tmp/crontab.tmp
    
    echo
    colorize green "Cron-job added successfully to restart the service '$service_name'." bold
    sleep 2
}

delete_cron_job() {
    echo
    local service_name="easymesh.service"
    local reset_path="/root/easytier/reset.sh"
    
    crontab -l | grep -v "#$service_name" | crontab -
    rm -f "$reset_path" >/dev/null 2>&1
    
    colorize green "Cron job for $service_name deleted successfully." bold
    
    sleep 2
}

set_cronjob(){
   	clear
   	colorize cyan "Cron-job setting menu" bold
   	echo 
   	
   	colorize green "1) Add a new cronjob"
   	colorize red "2) Delete existing cronjob"
   	colorize reset "3) Return..."
   	
   	echo
   	echo -ne "Select you option [1-3]: "
   	read -r choice
   	
   	case $choice in 
   		1) add_cron_job ;;
   		2) delete_cron_job ;;
   		3) return 0 ;;
   		*) colorize red "Invalid option!" && sleep 1 && return 1 ;;
   	esac
   	
}

# Function to display menu
display_menu() {
    clear
# Print the header with colors
echo -e "   ${CYAN}╔════════════════════════════════════════╗"
echo -e "   ║            🌐 ${WHITE}EasyMesh                 ${CYAN}║"
echo -e "   ║        ${WHITE}VPN Network Solution            ${CYAN}║"
echo -e "   ╠════════════════════════════════════════╣"
echo -e "   ║  ${WHITE}Version: 0.94 beta                    ${CYAN}║"
echo -e "   ║  ${WHITE}Developer: Musixal                    ${CYAN}║"
echo -e "   ║  ${WHITE}Telegram Channel: @Gozar_Xray         ${CYAN}║"
echo -e "   ║  ${WHITE}GitHub: github.com/Musixal/easy-mesh  ${CYAN}║"
echo -e "   ╠════════════════════════════════════════╣"
echo -e "   ║        ${WHITE}EasyMesh Core Installed         ${CYAN}║"
echo -e "   ╚════════════════════════════════════════╝${RESET}"

    echo ''
    colorize green "	[1] Connect to the Mesh Network" bold 
    colorize yellow "	[2] Display Peers" 
    colorize cyan "	[3] Display Routes" 
    colorize reset "	[4] Peer-Center"
    colorize reset "	[5] Display Secret Key"
    colorize reset "	[6] View Service Status"  
    colorize reset "	[7] Set Watchdog [Auto-Restarter]"
    colorize reset "	[8] Cron-jon setting"   
    colorize yellow "	[9] Restart Service" 
    colorize magenta "	[10] Remove Service" 
    echo -e "	[0] Exit" 
    echo ''
}


# Function to read user input
read_option() {
	echo -e "\t-------------------------------"
    echo -en "\t${MAGENTA}\033[1mEnter your choice:${RESET} "
    read -p '' choice 
    case $choice in
        1) connect_network_pool ;;
        2) display_peers ;;
        3) display_routes ;;
        4) peer_center ;;
        5) show_network_secret ;;
        6) view_service_status ;;
        7) set_watchdog ;;
        8) set_cronjob ;;
        9) restart_easymesh_service ;;
        10) remove_easymesh_service ;;
        0) exit 0 ;;
        *) colorize red "	Invalid option!" bold && sleep 1 ;;
    esac
}

# Main script
while true
do
    display_menu
    read_option
done
