#include <Wire.h>
#include <Biodome.h>

LM335TempSensor Temp(2);

void setup()
{
    Serial.begin(9600);
    Temp.name = "Temperature";
}

void loop()
{
	Temp.update();
	Serial.print("temp: ");
	Serial.println(Temp.read());

	delay(1000);
}


