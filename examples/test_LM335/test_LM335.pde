#include <Wire.h>
#include <Biodome.h>

LM335TemperatureSensor Temp(0);

void setup()
{
    Serial.begin(9600);
    Temp.configure("Temperature", 0);
}

void loop()
{
	Temp.update();
	Serial.print("temp: ");
	Serial.println(Temp.read());
	delay(1000);
}


