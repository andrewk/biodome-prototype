#include <Wire.h>
#include <Biodome.h>

Device Relay;

void setup()
{
  Serial.begin(9600);
  Relay.configure(13, false);
}

void loop()
{
  Serial.print("Turn on...");
  Relay.queuedStatus = 1;
  Relay.nextStatus();
  Serial.print(Relay.status);
  Serial.println("on!");
  delay(6000);

  Serial.print("Turn off...");
  Relay.queuedStatus = 0;
  Relay.nextStatus();
  Serial.print(Relay.status);
  Serial.println("off!");
  delay(1000);
}


