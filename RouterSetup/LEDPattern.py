import RPi.GPIO as GPIO
from time import sleep

GPIO.setmode(GPIO.BCM)

LEDPin = 17

# Setup the pin the LED is connected to
GPIO.setup(LEDPin, GPIO.OUT)

ledState = False
#Pattern: duty (turnon count), maxcount, sleeptime (for each count)
switcher = { 
        0:  [11, 10, .25],   
  1:  [8, 10, .25],
  2:  [6, 10, .25],
  3:  [4, 10, .25],
  4:  [2, 10, .25],
  5:  [0, 10, .25]
}  
lenswitcher=len(switcher)-1
print "LEN: ",lenswitcher

try:
    while True:
  print ""
  with open('/dev/shm/ledpattern.txt','r') as myfile:
        mydata = int(myfile.read().replace('\n',''))
    print "DATA: ",mydata
    if mydata > lenswitcher :
      mydata = lenswitcher
    print "NEW DATA: ",mydata
    outvalue = switcher[mydata]
    duty = outvalue[0]
    maxcount = outvalue[1]
    sleeptime = outvalue[2]
            print "OUTVALUE:",outvalue," DUTY:",duty," MAXCOUNT:",maxcount," SLEEPTIME:",sleeptime
    for count in range(1,maxcount):
                if count > duty and ledState == False:
                  GPIO.output(LEDPin, True)
                  print "LED ON"
                  ledState = True
                elif count <= duty and ledState == True:
                  GPIO.output(LEDPin, False)
                  print "LED OFF"
                  ledState = False
          print "COUNT: ",count
                sleep(sleeptime)
finally:
    # Reset the GPIO Pins to a safe state
    GPIO.output(LEDPin, False)
    GPIO.cleanup()
