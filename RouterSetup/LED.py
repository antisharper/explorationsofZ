import RPi.GPIO as GPIO
from time import sleep

GPIO.setmode(GPIO.BCM)

maxcount = 8
count = 0
duty = 4
LEDPin = 17

# Setup the pin the LED is connected to
GPIO.setup(LEDPin, GPIO.OUT)

ledState = True

try:
    while True:
        if count > duty and ledState == False:
            GPIO.output(LEDPin, True)
            print("LED ON")
            ledState = True
        elif count <= duty and ledState == True:
            GPIO.output(LEDPin, False)
            print("LED OFF")
            ledState = False
        count += 1
  if count > maxcount: count = 1 
        sleep(0.5)
finally:
    # Reset the GPIO Pins to a safe state
    GPIO.output(LEDPin, False)
    GPIO.cleanup()
