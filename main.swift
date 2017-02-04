import Glibc
import Foundation

func initLCD() -> HD44780LCD {
	let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPi2)
	let lcd = HD44780LCD(rs:gpios[.P25]!,e:gpios[.P24]!,d7:gpios[.P22]!,d6:gpios[.P27]!,d5:gpios[.P17]!,d4:gpios[.P23]!,width:20,height:4)
	return lcd
}

let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPi2)
let lcd = initLCD()
lcd.clearScreen()
lcd.cursorHome()

let dht = DHT(pin: gpios[.P4]!, for: .dht22)

var temperature = 0.0
var humidity = 0.0

// samples every 5s, outputs last good temp/humidty & the # of seconds since last good reading
var startTime:timeval = timeval(tv_sec: 0, tv_usec: 0)
var endTime:timeval = timeval(tv_sec: 0, tv_usec: 0)

gettimeofday(&startTime,nil)
while (true) {
	do {
		(temperature,humidity) = try dht.read(true)
		gettimeofday(&startTime,nil)
		print("temp: \(temperature)  hum: \(humidity)")
	} catch (DHTError.invalidNumberOfPulses) {
		let errorMessage = "INVALID PULSES"
		print(errorMessage)
	} catch (DHTError.invalidChecksum) {
		let errorMessage = "INVALID CHECKSUM"
		print(errorMessage)
	}
	
	gettimeofday(&endTime,nil)
	
	lcd.clearScreen()
	lcd.cursorHome()
	lcd.printString(0,y:0,what:"Temp: \(temperature) \(endTime.tv_sec - startTime.tv_sec)s",usCharSet:true)
	lcd.printString(0,y:1,what:"Humidity: \(humidity)",usCharSet:true)
	
	sleep(5)		
}
