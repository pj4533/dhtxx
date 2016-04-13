dhttest: main.swift SwiftyGPIO.swift HD44780CharacterLCD.swift dht.swift
	@~/usr/bin/swiftc main.swift SwiftyGPIO.swift HD44780CharacterLCD.swift dht.swift -o dhttest

HD44780CharacterLCD.swift: 
	@wget https://raw.githubusercontent.com/uraimo/HD44780CharacterLCD.swift/master/Sources/HD44780CharacterLCD.swift

SwiftyGPIO.swift:
	@wget https://raw.githubusercontent.com/uraimo/SwiftyGPIO/master/Sources/SwiftyGPIO.swift

