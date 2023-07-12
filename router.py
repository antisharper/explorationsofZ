#!/bin/python3
import subprocess
import socket
import operator
import datetime
import re
import sys
import argparse
from flask import Flask, render_template, request

# Install
# apt install -y python3-flask python3-openssl
#
# GitHub Dir:
# Copy *doscan* *png site* *router*
#
# useful commands:
# watch -n5 --difference 'echo +++++++ IFCONFIG WLAN1; ifconfig wlan1; echo +++++++++++++++ WPA SUPPLICANT WLAN1; sudo wpa_cli -i wlan1 status ; echo +++++++++++++++ HOSTAPD WLAN0; sudo hostapd_cli -i wlan0 status; echo ++++++++++++++++++++++ WPA SUPPLICANT ; cat /etc/wpa_supplicant/wpa_supplicant-wlan1.conf'

wpa_filename = "/etc/wpa_supplicant/wpa_supplicant-wlan1.conf"
bindaddrport ="0.0.0.0:8443"
debugmode=True

parser = argparse.ArgumentParser(description="Router Controller",
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-d", "--debug", action="store_true", help="Debug Mode")
parser.add_argument("-b", "--bindaddrport", help="Addr and Port to bind webserver")
parser.add_argument("--wpa_supplicant", help="Full path to wpa_supplicant-wlanX.conf file")
args = parser.parse_args()
config = vars(args)

debugmode=config['debug'];
if config['bindaddrport']:
    bindaddrport=config['bindaddrport']
if config['wpa_supplicant']:
    wpa_filename=config['wpa_supplicant'] 

app = Flask(__name__, template_folder='./')

def get_currentuplink():
    cur_uplink_command_str = "sudo wpa_cli -i wlan1 status | sed '/^ssid=/!d;s/ssid=//'"
    try:
        uplink_output = subprocess.check_output(cur_uplink_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        uplink_output = str(e)

    currentuplink = (uplink_output.strip().split("\n"))[0]
    #if currentuplink is None:
    #    currentuplink="*-*-*-*-*"
    print(f"currentuplink: {currentuplink}")

    return currentuplink    


def reconfigure_wlan1():
    reconfigure_command_str = 'sudo wpa_cli -i wlan1 flush;  sleep 3; sudo wpa_cli -i wlan1 reconfigure'
    # print("reconfigure_command_str:",reconfigure_command_str)

    try:
        reconfigure_output = subprocess.check_output(reconfigure_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        # Handle the subprocess error
        reconfigure_output = str(e)

    print("Raw reconfigure_output:",reconfigure_output)


def read_wpasupplicant(filename):
    # Read the contents of the file
    with open(filename, "r") as file:
        wpa_supplicant_file = file.read()

    defined_uplinks = []
    listed_wifi = {}
    for line in wpa_supplicant_file.split('\n'):
        #print("Line =", line)
        if not listed_wifi:
            #print("\tNo Current Networks")
            if "network={" in line:
                #print("\t\tFound Network")
                listed_wifi["enabled"] = True
                if line.startswith("#"):
                    #print("\t\t\tFound Disabled Network")
                    listed_wifi["enabled"] = False
        else:
            #print("\tProcessing Found Network")
            if line.endswith("}"):
                #print("\tCompleted Processing Found Network")
                if not ( "priority" in listed_wifi ):
                    listed_wifi['priority'] = -1
                else:
                    listed_wifi['priority'] = int(listed_wifi['priority'])
                defined_uplinks.append(listed_wifi)
                #print("\t\tAdded Listed_wifi:", listed_wifi)
                listed_wifi = {}
            else:
                if "=" in line:
                    #print("\t\tCreating Key Value Pairs")
                    #key, value = re.findall(r'(\w+)\s*=\s*(".*?"|\w+)', line)[0]
                    key, value = re.findall(r'(\w+)\s*=\s*(.*)', line)[0]
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]  # Remove double quotes if present
                    listed_wifi[key] = value
    
    return defined_uplinks

def save_wpasupplicant(filename, defined_uplinks, force_wpacli=True):
    #print("Saving Defined_uplinks:",defined_uplinks)
    # Remove lines after the first blank line
    with open(filename, 'r') as file:
        lines = file.readlines()
    with open(filename, 'w') as file:
        for line in lines:
            file.write(line)
            if line.strip().startswith("########"):
                break
        file.write("\n########\n")
    
    # Save the updated defined_uplinks to the wpa_supplicant file
    with open(filename, 'a') as file:
        for uplink in sorted(defined_uplinks,key=operator.itemgetter('priority'), reverse=True):
            if uplink.get('enabled', False):
                leed=""
            else:
                leed="#"
            #print("\t" + leed + "network={")
            file.write(leed + "network={\n")
            for key, value in uplink.items():
                if key != 'enabled':
                    if not (key == 'priority' and value < 0):
                        if key in ["priority","key_mgmt", "scan_ssid"]:
			    #print("\t" + f"{leed}    {key}={value}")
                            file.write(f'{leed}    {key}={value}' + "\n")
                        else:
                            #print("\t" + f"{leed}    {key}=\"{value}\"")
                            file.write(f'{leed}    {key}="{value}"' + "\n")
            #print("\t" + leed + "}")
            file.write(leed + "}\n")
            #print("\t" + "########")
            file.write("########\n")

   
    if force_wpacli:   
        reconfigure_wlan1()

@app.route('/')
@app.route('/index.html')
def index():
    # Execute the tail and sed commands and capture the output
    hostname = socket.gethostname()
    status_command_str = 'tail -150 /dev/shm/log-monitor.out | sed "/'+ hostname +'/,\$!d"'
    # print("status_command_str:",status_command_str)

    try:
        status_output = subprocess.check_output(status_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        # Handle the subprocess error
        status_output = str(e)

    # print("Raw Status_output:",status_output)

    status_output = re.sub(r'^\*', '</pre><br /><pre>', status_output, flags=re.MULTILINE)
    status_output += "</pre>"
    # print("Cooked Status_output:",status_output)

    return render_template('router_index.html', status_output=status_output)

@app.route('/change_uplink')
def change_uplink():

    defined_uplinks = read_wpasupplicant(wpa_filename)

    hostap_command = "tail -150 /dev/shm/log-monitor.out | grep -iE ^access\ point | tail -1 | sed s/.*\ //"
    try:
        hostap_output = subprocess.check_output(hostap_command, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        hostap_output = str(e)

    localap = hostap_output.strip().split("\n")
    print(f"localap: {localap[0]}")

    currentuplink = get_currentuplink()

    found_wifi_command_str = "sudo ./doscan.sh -i wlan1 -c"
    try:
        wifi_output = subprocess.check_output(found_wifi_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        wifi_output = str(e)

    wifi_output = wifi_output.strip().split("\n")
    header = wifi_output[0]
    rows = wifi_output[1:]
    found_wifi = []

    for row in rows:
        entry = row.split(",")
        wifi_name = entry[0]
        found_wifi.append({
            'disabled': False,
            'Network': wifi_name,
            'ADDRESS': entry[1],
            'PROTOCOL': entry[2],
            'FREQUENCY': entry[3],
            'CHANNEL': entry[4],
            'ENCRYPT': entry[5],
            'BITRATE': entry[6] if entry[6] else "0",
            'QUALITY': int(entry[7]) if entry[7] else 0,
            'SIGNAL': int(entry[8]) if entry[8] else 0
        })

    # Convert bitrate from Gb/s to Mb/s in found_wifi
    for wifi in found_wifi:
        if 'BITRATE' in wifi:
            bitrate = wifi['BITRATE']
            if bitrate.endswith(' Gb/s'):
                bitrate = float(bitrate.split(' ',1)[0])
                bitrate = int(bitrate*1000)
            elif bitrate.endswith(' Mb/s'):
                bitrate = float(bitrate.split(' ',1)[0])
            wifi['BITRATE'] = int(bitrate)

    # Sort found_wifi by Network (ascending) and wifi_name (descending)
    found_wifi = sorted(found_wifi,key=lambda w: (w['Network'], -w['BITRATE'], -w['SIGNAL']))

    uplink_names = [d['ssid'] for d in defined_uplinks]

    # Remove duplicate entries based on wifi_name, preferring larger BITRATE and SIGNAL
    unique_wifi = []
    seen_wifi_names = set()
    for wifi in found_wifi:
        if wifi['Network'] not in seen_wifi_names and wifi['Network'] not in uplink_names and wifi['Network'] != localap[0]:
            unique_wifi.append(wifi)
            seen_wifi_names.add(wifi['Network'])
        else:
            # Check if current wifi has larger BITRATE or SIGNAL than the existing entry
            existing_wifi = next((w for w in unique_wifi if w['Network'] == wifi['Network']), None)
            if existing_wifi and (wifi['BITRATE'] > existing_wifi['BITRATE'] or wifi['SIGNAL'] > existing_wifi['SIGNAL']):
                unique_wifi.remove(existing_wifi)
                unique_wifi.append(wifi)

    #for wifi in unique_wifi:
    #    print("\t" + f"{wifi['Network']}, {wifi['BITRATE']}, {wifi['SIGNAL']}")


    found_wifi = unique_wifi

    return render_template('router_change_uplink.html', currentuplink=currentuplink, localap=localap[0], found_wifi=found_wifi, defined_uplinks=defined_uplinks)

@app.route('/toggle_uplink')
def toggle_uplink():
    args = request.args
    network = args.get('network')
    enable = args.get('network')

    defined_uplinks = read_wpasupplicant(wpa_filename)
    for uplink in defined_uplinks:
        if uplink['ssid'] == network:
            uplink['enabled'] = not uplink.get('enabled', False)
            #print("\t\t\tToggling: " + uplink['ssid'] + " (" + network + ")\n")

    uplink_enable = [d['enabled'] for d in defined_uplinks]
    
    save_wpasupplicant(wpa_filename, defined_uplinks, get_currentuplink() == "*-*-*-*-*" or get_currentuplink() == network or enable == "Enabled")

    return "Success", 204

@app.route('/reconfigure', methods=['GET'])
def reconfigure():
    reconfigure_wlan1()

    return "Success",200

@app.route('/set_uplink_priority', methods=['GET'])
def set_uplink_priority():
    network = request.args.get('network')
    priority = int(request.args.get('priority'))

    defined_uplinks = read_wpasupplicant(wpa_filename)

    for uplink in defined_uplinks:
        if uplink['ssid'] == network:
            uplink['priority'] = priority

    save_wpasupplicant(wpa_filename, defined_uplinks, get_currentuplink() == "*-*-*-*-*" or get_currentuplink() == network)

    return "Success",204

@app.route('/delete_uplink', methods=['GET'])
def delete_uplink():
    network = request.args.get('network')

    defined_uplinks = read_wpasupplicant(wpa_filename)

    # Find the index of the uplink with the matching network (SSID)
    index = next((i for i, uplink in enumerate(defined_uplinks) if uplink['ssid'] == network), None)

    if index is not None:
        # Delete the uplink from the defined_uplinks list
        del defined_uplinks[index]

        # Save the updated defined_uplinks to the wpa_supplicant file
        save_wpasupplicant(wpa_filename, defined_uplinks,get_currentuplink() == "*-*-*-*-*" or get_currentuplink() == network)

    # Redirect back to the change_uplink route
    return "Success", 204

@app.route('/reboot_router', methods=['GET'])
def reboot_router():
    reboot_command_str = 'sudo reboot'
    # print("reconfigure_command_str:",reconfigure_command_str)

    try:
        reboot_output = subprocess.check_output(reboot_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        # Handle the subprocess error
        reboot_output = str(e)

    print("Raw reboot_output:",reboot_output)
    return redirect(url_for('index'))
    
@app.route('/stop_openvpn', methods=['GET'])
def stop_openvpn():
    stop_openvpn_command_str = 'sudo bash disconnect-openvpn.sh'
    # print("stop_openvpn_command_str:",stop_openvpn_command_str)

    try:
        stop_openvpn_output= subprocess.check_output(stop_openvpn_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        # Handle the subprocess error
        stop_openvpn_output = str(e)

    print("Raw stop_openvpn_output:",stop_openvpn_output)
    return redirect(url_for('index'))

@app.route('/restart_openvpn', methods=['GET'])
def restart_openvpn():
    restart_openvpn_command_str = 'sudo bash disconnect-openvpn.sh; sleep 10;sudo bash connect-openvpn.sh'
    # print("restart_openvpn_command_str:",restart_openvpn_command_str)

    try:
        restart_openvpn_output= subprocess.check_output(restart_openvpn_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        # Handle the subprocess error
        restart_openvpn_output = str(e)

    print("Raw restart_openvpn_output:",restart_openvpn_output)
    return redirect(url_for('index'))

@app.route('/create_uplink', methods=['POST'])
def create_uplink():
    wifi_name = request.form.get('wifi-name')
    description = request.form.get('description')
    secret_password = request.form.get('secret-password')
    priority = request.form.get('priority')

    # Append the values to the wpa_filename file
    with open(wpa_filename, 'a') as file:
        file.write('network={\n')
        file.write('    ssid="' + wifi_name + '"\n')
        file.write('    id_str="' + description + '"\n')
        if priority and int(priority) >= 0:
            file.write('    priority=' + priority + '\n')
        if secret_password:
            file.write('    key_mgmt=WPA-PSK\n')
            file.write('    psk="' + secret_password + '"\n')
        else:
            file.write('    key_mgmt=NONE\n')
        file.write('    scan_ssid=1\n')
        file.write('}\n')


    if wifi_name == get_currentuplink():
        reconfigure_wlan1()

    return 'Success', 204

@app.route('/android-chrome-192x192.png')
@app.route('/android-chrome-512x512.png')
@app.route('/apple-touch-icon.png')
@app.route('/favicon-16x16.png')
@app.route('/favicon-32x32.png')
@app.route('/site.webmanifest')
def statics():
    return render_template(request.path)

if __name__ == '__main__':
    app.run(host=(bindaddrport.split(":"))[0],ssl_context='adhoc',port=(bindaddrport.split(":"))[1], debug=debugmode)

