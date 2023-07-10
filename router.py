#!/bin/python3
import subprocess
import socket
import operator
import re
from flask import Flask, render_template, request

wpa_filename = "/etc/wpa_supplicant/wpa_supplicant-wlan1.conf"
app = Flask(__name__, template_folder='./')

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
                    key, value = re.findall(r'(\w+)\s*=\s*(".*?"|\w+)', line)[0]
                    if value.startswith('"') and value.endswith('"'):
                        value = value[1:-1]  # Remove double quotes if present
                    listed_wifi[key] = value
    
    return defined_uplinks

def save_wpasupplicant(filename, defined_uplinks):
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
                       #print("\t" + f"{leed}    {key}={value}")
                       file.write(f'{leed}    {key}="{value}"' + "\n")
            #print("\t" + leed + "}")
            file.write(leed + "}\n")
            #print("\t" + "########")
            file.write("########\n")

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

    links = [
        {'name': 'Change Uplink', 'url': '/change_uplink'},
        {'name': 'Change Hostname', 'url': '/change_hostname'},
        {'name': 'Change AP Network Name', 'url': '/change_network_name'},
        {'name': 'Change Network Octet', 'url': '/change_network_octet'},
        {'name': 'Change AP Password', 'url': '/change_ap_password'},
        {'name': 'Change Update Port', 'url': '/change_update_port'},
        {'name': 'Update SSH PUB Key', 'url': '/update_ssh_pub_key'},
        {'name': 'Regenerate SSH HOST Key', 'url': '/regenerate_ssh_host_key'}
    ]

    return render_template('router_index.html', status_output=status_output, links=links)

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

    cur_uplink_command_str = "tail -150 /dev/shm/log-monitor.out | grep -iE ESSID: | sed s/.*ESSID:.//\;s/\\\".*//"
    try:
        uplink_output = subprocess.check_output(cur_uplink_command_str, shell=True, encoding='utf-8')
    except subprocess.CalledProcessError as e:
        uplink_output = str(e)

    currentuplink = uplink_output.strip().split("\n")
    print(f"currentuplink: {currentuplink[0]}")

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
        if wifi_name == localap[0]:
            wifi_name += " -- Your Device Access Point"
        if wifi_name == currentuplink[0]:
            wifi_name += " -- Current WiFi Uplink"
        found_wifi.append({
            'disabled': False,
            'Network': wifi_name,
            'ADDRESS': entry[1],
            'PROTOCOL': entry[2],
            'FREQUENCY': entry[3],
            'CHANNEL': entry[4],
            'ENCRYPT': entry[5],
            'BITRATE': entry[6],
            'QUALITY': int(entry[7]),
            'SIGNAL': int(entry[8])
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

    # Remove duplicate entries based on wifi_name, preferring larger BITRATE and SIGNAL
    unique_wifi = []
    seen_wifi_names = set()
    for wifi in found_wifi:
        if wifi['Network'] not in seen_wifi_names:
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

    return render_template('router_change_uplink.html', currentuplink=currentuplink[0], localap=localap[0], found_wifi=found_wifi, defined_uplinks=defined_uplinks)

@app.route('/toggle_uplink')
def toggle_uplink():
    args = request.args
    network = args.get('network')

    defined_uplinks = read_wpasupplicant(wpa_filename)
    for uplink in defined_uplinks:
        if uplink['ssid'] == network:
            uplink['enabled'] = not uplink.get('enabled', False)
            #print("\t\t\tToggling: " + uplink['ssid'] + " (" + network + ")\n")

    save_wpasupplicant(wpa_filename, defined_uplinks)

    return "Success", 204

@app.route('/set_uplink_priority', methods=['GET'])
def set_uplink_priority():
    network = request.args.get('network')
    priority = int(request.args.get('priority'))

    defined_uplinks = read_wpasupplicant(wpa_filename)

    for uplink in defined_uplinks:
        if uplink['ssid'] == network:
            uplink['priority'] = priority

    save_wpasupplicant(wpa_filename, defined_uplinks)

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
        save_wpasupplicant(wpa_filename, defined_uplinks)

    # Redirect back to the change_uplink route
    return "Succes", 204

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
            file.write('    key_mgmt=WPA\n')
            file.write('    psk="' + secret_password + '"\n')
        else:
            file.write('    key_mgmt="NONE"\n')
        file.write('    scan_ssid=1\n')
        file.write('}\n')

    return 'Success', 204

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)

