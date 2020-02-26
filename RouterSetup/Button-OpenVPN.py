import gpiozero  # We are using GPIO pins
import subprocess
import os
from time import sleep

checkFile="/dev/shm/no-openvpn"
channel = 21 
button = gpiozero.Button(channel)
toggle = False

# Toggle False = Allow Openvpn (Remove /dev/shm/no-openvpn)
# Toggle True = Stop Openvpn (Create /dev/shm/no-openvpn * kill openvpn --config processes)
 
while True:
  if button.is_pressed: 
    if  lastButton == False:
      lastButton = True
      toggle = not toggle
      print("Flip Toggle to " + str(toggle))
      if toggle:
  print("Disable OpenVPN")
  os.system("touch " + checkFile)
        os.system("ps -ef | grep -v grep | grep \"openvpn --config\"| awk \'{print $2}\' | xargs kill ")
      else:
  print("Enable OpenVPN")
  os.system("rm -f " + checkFile)
  else:
    lastButton = False
  sleep(.25)
