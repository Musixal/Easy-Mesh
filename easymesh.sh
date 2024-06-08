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
    openssl rand -hex 16
}

#Var
EASY_CLIENT='/root/easytier/easytier-cli'
SERVICE_FILE="/etc/systemd/system/easymesh.service"
    
connect_network_pool(){
	clear
	colorize cyan "Coonect to the Mesh Network" bold 
	echo ''
	
	read -p "[-] Enter Peer IPv4/IPv6 Address: " PEER_ADDRESS
     if [[ "$PEER_ADDRESS" == *:* ]]; then
        # Check if the IP address already has brackets
        if [[ "$PEER_ADDRESS" != \[*\] ]]; then
            PEER_ADDRESS="[$PEER_ADDRESS]"
        fi
    fi
    
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
	
	if [ ! -z $PEER_ADDRESS ]; then
		PEER_ADDRESS="--peers ${DEFAULT_PROTOCOL}://${PEER_ADDRESS}:${PORT}"
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

# Function to display menu
display_menu() {
    clear
# Print the header with colors
echo -e "   ${CYAN}╔════════════════════════════════════════╗"
echo -e "   ║            🌐 ${WHITE}EasyMesh                 ${CYAN}║"
echo -e "   ║        ${WHITE}VPN Network Solution            ${CYAN}║"
echo -e "   ╠════════════════════════════════════════╣"
echo -e "   ║  ${WHITE}Version: 0.92 beta                    ${CYAN}║"
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
    colorize yellow "	[7] Restart Service" 
    colorize magenta "	[8] Remove Service" 
    echo -e "	[9] Exit" 
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
        7) restart_easymesh_service ;;
        8) remove_easymesh_service ;;
        9) exit 0 ;;
        *) colorize red "	Invalid option!" bold && sleep 1 ;;
    esac
}

# Main script
while true
do
    display_menu
    read_option
done
