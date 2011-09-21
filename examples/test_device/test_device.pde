#include <Wire.h>
#include <Biodome.h>

Device Relay;

void setup()
{
    Serial.begin(9600);
	Relay.configure("Test device", 2, true);
}

void loop()
{
	Serial.print("Turn on...");
	Relay.queuedStatus = 1;
	Relay.nextStatus();
	Serial.println("on!");
	delay(1000);

	Serial.print("Turn off...");
	Relay.queuedStatus = 1;
	Relay.nextStatus();
	Serial.println("off!");
	delay(1000);
}


