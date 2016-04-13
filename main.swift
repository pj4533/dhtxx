import Glibc
import Foundation

func initLCD() -> HD44780LCD {
	let gpios = SwiftyGPIO.getGPIOsForBoard(.RaspberryPiRev2)
	let lcd = HD44780LCD(rs:gpios[.P25]!,e:gpios[.P24]!,d7:gpios[.P22]!,d6:gpios[.P27]!,d5:gpios[.P17]!,d4:gpios[.P23]!,width:20,height:4)
	return lcd	
}

	let gpios = SwiftyGPIO.getGPIOsForBoard(.RaspberryPiRev2)

	let lcd = initLCD()
	lcd.clearScreen()
	lcd.cursorHome()

	let dht = DHT(pin: gpios[.P4]!)

	while (true) {
		lcd.clearScreen()
		lcd.cursorHome()
		lcd.printString(0,y:0,what:"Reading...",usCharSet:true)
		do {
			let (temperature,humidity) = try dht.read(true)
			lcd.clearScreen()
			lcd.cursorHome()
			print("temp: \(temperature)  hum: \(humidity)")
			lcd.printString(0,y:0,what:"Temp: \(temperature)",usCharSet:true)
			lcd.printString(0,y:1,what:"Humidity: \(humidity)",usCharSet:true)
		} catch (DHTError.InvalidNumberOfPulses) {
			let errorMessage = "INVALID PULSES"
			lcd.clearScreen()
			lcd.cursorHome()
			lcd.printString(0,y:0,what:errorMessage,usCharSet:true)
			print(errorMessage)
		} catch (DHTError.InvalidChecksum) {
			let errorMessage = "INVALID CHECKSUM"
			lcd.clearScreen()
			lcd.cursorHome()
			lcd.printString(0,y:0,what:errorMessage,usCharSet:true)
			print(errorMessage)
		}
	
		sleep(10)		
	}

