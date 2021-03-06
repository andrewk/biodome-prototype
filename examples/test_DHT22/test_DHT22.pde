#include <Wire.h>
#include <DHT.h>
#include <Biodome.h>

#define DHTTYPE DHT22
#define DHTPIN 11

FacadeSensor Temp;
FacadeSensor Humidity;
DHT dht(DHTPIN, DHTTYPE);


void setup()
{
  Serial.begin(9600);
  Temp.configure("Temperature", 0);
  Humidity.configure("Humidity", 0);
  dht.begin();
  delay(10000);
}

void loop()
{
  Temp.updateExternal(dht.readTemperature());
  Humidity.updateExternal(dht.readHumidity());

  Serial.print("temp: ");
  Serial.println(Temp.read());

  Serial.print("humidity: ");
  Serial.println(Humidity.read());

  delay(7000);
}


