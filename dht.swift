import Glibc
import Foundation

enum DHTError: ErrorType {
    case InvalidNumberOfPulses
    case InvalidChecksum
}

public class DHT {
	var pin: GPIO

	init(pin:GPIO) {
		self.pin = pin
	}

	func setMaxPriority() {
		var sched: sched_param = sched_param()
  		// Use FIFO scheduler with highest priority for the lowest chance of the kernel context switching.
  		sched.__sched_priority = sched_get_priority_max(SCHED_FIFO)
  		if (sched_setscheduler(0, SCHED_FIFO, &sched) != 0) {
  			print("ERROR")
  		}
	}

	func setDefaultPriority() {
		var sched: sched_param = sched_param()
		// Go back to default scheduler with default 0 priority.
		sched.__sched_priority = 0;
		sched_setscheduler(0, SCHED_OTHER, &sched)
	}

	func binaryStringForNumber(number: UInt8) -> String {
		return self.binaryStringForNumber(Int(number))
	}

	func binaryStringForNumber(number: Int) -> String {
			let str = String(number, radix:2) //binary base
			let padd = String(count: (8 - str.characters.count), repeatedValue: Character("0")) //repeat a character
			return String(padd + str)
	}

	func read(debug: Bool = false) throws -> (temperature: Double, humidity: Double) {

		if debug { print("----------------------------------")}

		// Number of bit pulses to expect from the DHT.  Note that this is 41 because
		// the first pulse is a constant 50 microsecond pulse, with 40 pulses to represent
		// the data afterwards.
		let kDHT_PULSES: Int = 41

		var temperature = 0.1
		var humidity = 0.1

		// Store the count that each DHT bit pulse is low and high
		// Making these arrays bigger tho cause sometimes we do catch the initial
		// pulse, but sometimes usually not.  yay for nonrealtime  
		var lowPulseTimes = [Int](count:kDHT_PULSES + 1, repeatedValue: 0)
		var highPulseTimes = [Int](count:kDHT_PULSES + 1, repeatedValue: 0)

		// Set pin to output
		self.pin.direction = .OUT

		var prevValue = 1
		var lowpulse = 0
		var highpulse = 0

		var startTime:timeval = timeval(tv_sec: 0, tv_usec: 0)
		var endTime:timeval = timeval(tv_sec: 0, tv_usec: 0)

		// The data sheet says the 'start signal' is having the microcontroller
		// setting LOW for 1-10ms, then pull HIGH and wait for response from 
		// the AM2302 -- I found that if I did this, I never got good results,
		// possibly because after sending LOW, I couldn't pull HIGH and
		// switch to direction INPUT fast enough to start processing data?
		// but if i just left it low, then switched to input I could get the pulses
		// -- usually.

		// I did find marginally better results by bumping up the priority of the thread
		// but only marginally, it still fails ALOT -- A. LOT.  Sampling every 5s I can
		// usually get a good reading within the past 60s, many times more often than that
		// but def not every time.  
		self.setMaxPriority()

		// Set pin low 
		self.pin.value = 0

		usleep(10000)

		// see comment above
		// self.pin.value = 1

		// Set pin to in
		self.pin.direction = .IN

		// This is tough -- most other code I read had while loops, with
		// timeouts -- i took a different approach and just spin in a for-loop
		// constantly sampling the pin and comparing to the previous value.
		// The end result is the same, but this way I'll never get stuck in a while-loop
		// or have to mess with timeouts -- and this just makes more sense to me
    	gettimeofday(&startTime,nil)
		for _ in 0..<5000000 {
			if self.pin.value != prevValue {
		    	gettimeofday(&endTime,nil)
		    	let pulseTime = endTime.tv_usec - startTime.tv_usec
				if prevValue == 0 {
					lowPulseTimes[lowpulse] = pulseTime
					lowpulse = lowpulse + 1
				} else {
					highPulseTimes[highpulse] = pulseTime
					highpulse = highpulse + 1
				}
				prevValue = self.pin.value
				gettimeofday(&startTime,nil)
			}
		}

		// Done with timing code, interpret the results
		self.setDefaultPriority()

		// This is a big hack -- if the timings are off, and i only get 40 pulses, I know the first one is low -- so regardless set it
		// this helps us get better results -- but yeah...super hack
		highPulseTimes[0] = 0


		if debug {
			print("LOW PULSE TIMINGS (\(lowpulse)): \(lowPulseTimes)")
			print("HIGH PULSE TIMINGS (\(highpulse)): \(highPulseTimes)")			
		}

		guard highpulse >= 40 else { throw DHTError.InvalidNumberOfPulses }

		//  Data sheet says 0bit pulses are ~28us, and 1bit pulses are ~70us
		//
		//  this stuff with 'highSkip', are accounting for when we actually get the pulses
		//  during the startup signal.  Usually, this is missed, but the array size and
		//  this offset account for that.   
  		let highSkip = highpulse - 40
  		var data = [UInt8](count:5, repeatedValue: 0)
  		var prevIndex = 0
  		for i in highSkip..<(40+highSkip) {
  			let index = (i-highSkip) / 8
  			data[index] <<= 1
  			if prevIndex != index {
  				prevIndex = index
  			}
  			if highPulseTimes[i] >= 30 {
  				// One bit for long pulse
  				data[index] |= 1
  			}
  			// else zero bit for short pulse
  		}

  		// checksum is UPPER 8 BITS of the sum of the other values
		let computedChecksum = (Int(data[0]) + Int(data[1]) + Int(data[2]) + Int(data[3])) & 0xFF
  		if debug {
			print("Computed checksum: \(self.binaryStringForNumber(computedChecksum))(\(computedChecksum)) = (\(self.binaryStringForNumber(data[0]))(\(data[0])) + \(self.binaryStringForNumber(data[1]))(\(data[1])) + \(self.binaryStringForNumber(data[2]))(\(data[2])) + \(self.binaryStringForNumber(data[3]))(\(data[3]))) & 0xFF")
			print("  Actual checksum: \(self.binaryStringForNumber(data[4]))(\(data[4]))")
		}

  		// Verify checksum of received data
  		if (data[4] == UInt8(computedChecksum))  {
  			// DHT11
  			// humidity = Double(data[0])
  			// temperature = Double(data[2])

  			// only doing DHT22 for now
  			humidity = ((Double(data[0]) * 256.0) + Double(data[1])) / 10.0
  			temperature = ((Double(data[2] & 0x7F) * 256.0) + Double(data[3])) / 10.0
  			if ((data[2] & 0x80) != 0) {
  				temperature = temperature * -1.0
  			}
  			temperature = (temperature * 1.8) + 32
  		} else {
  			throw DHTError.InvalidChecksum
  		}

		if debug { print("----------------------------------")}

		return (temperature,humidity)
	}
}