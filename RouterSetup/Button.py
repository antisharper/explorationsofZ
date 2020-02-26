import gpiozero  # We are using GPIO pins
from time import sleep
channel = 21 
button = gpiozero.Button(channel)
 
while True:
  if button.is_pressed:
    print("Button is pressed!")
  else:
    print("Button is not pressed!")
  sleep(1)
