#include <Wire.h>
#include <Biodome.h>

#define COUNT_DEVICES 8

Device D1;
Device D2;
Device D3;
Device D4;
Device D5;
Device D6;
Device D7;
Device D8;
Device * Devices[] = { &D1, &D2, &D3, &D4, &D5, &D6, &D7, &D8 };

void setup()
{
  Serial.begin(9600);
  D1.configure(2, true);
  D2.configure(3, true);
  D3.configure(4, true);
  D4.configure(5, true);
  D5.configure(6, true);
  D6.configure(7, true);
  D7.configure(8, true);
  D8.configure(9, true);
}

void loop()
{
  Serial.println("Turn on");
  for (byte ic = 0; ic < COUNT_DEVICES; ic++)
  {
    Devices[ic]->turnOn();
    delay(500);
  }

  Serial.println("Turn off");
  for (byte ic = 0; ic < COUNT_DEVICES; ic++)
  {
    Devices[ic]->turnOff();
    delay(500);
  }
}


