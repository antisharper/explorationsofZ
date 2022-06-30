import RPi.GPIO as GPIO
from time import sleep

GPIO.setmode(GPIO.BCM)

LEDPin = 17

# Setup the pin the LED is connected to
GPIO.setup(LEDPin, GPIO.OUT)

ledState = False
#Pattern: duty (turnon count), maxcount, sleeptime (for each count)
switcher = {
        0:  [0, 10, .25],
        1:  [2, 10, .25],
        2:  [4, 10, .25],
        3:  [6, 10, .25],
        4:  [8, 10, .25],
        5:  [11, 10, 1]
}


lenswitcher=len(switcher)-1
print "LEN: ",lenswitcher
mydata = 0

try:
	while True:
		print ""
		with open('/dev/shm/ledpattern.txt','r') as myfile:
			mydata = [ int(x) for x in next(myfile).split() ]
			print "DATA: ",mydata[0]
			if mydata[0] > lenswitcher:
				mydata[0] = lenswitcher
			print "NEW DATA: ",mydata[0]
			outvalue = switcher[mydata[0]]
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
				#print "COUNT: ",count
				sleep(sleeptime)
finally:
	# Reset the GPIO Pins to a safe state
	GPIO.output(LEDPin, False)
	GPIO.cleanup()
