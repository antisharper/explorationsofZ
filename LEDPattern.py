import RPi.GPIO as GPIO
from time import sleep

GPIO.setmode(GPIO.BCM)

LEDPin = 17

# Setup the pin the LED is connected to
GPIO.setup(LEDPin, GPIO.OUT)

ledState = False
#Pattern: duty (turnon count), maxcount, sleeptime (for each count)
switcher = {
        0:  [.10, .25, 5],
        1:  [.10, .25, 4],
        2:  [.10, .25, 3],
        3:  [.10, .25, 2],
        4:  [.10, .25, 1],
        5:  [0, 1, 0]
}
waitafter=1.5


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
			ontime = outvalue[0]
			offtime = outvalue[1]
			repeattimes = outvalue[2]
			print "ONTIME:",ontime," OFFTIME:",offtime," REPEATTIMES:",repeattimes," WAITAFTER:",waitafter
			for count in range(0,repeattimes):
				if ontime>0:
					GPIO.output(LEDPin, True)
					print "LED ON"
					ledState = True
					sleep(ontime)
				if offtime>0:
					GPIO.output(LEDPin, False)
					print "LED OFF"
			        	sleep(offtime)
			sleep(waitafter)
finally:
	# Reset the GPIO Pins to a safe state
	GPIO.output(LEDPin, False)
	GPIO.cleanup()
