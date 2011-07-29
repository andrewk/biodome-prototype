#include "WProgram.h"
#include "Biodome.h"


//==========================================================================//
// Model representation of a controlled relay with boolean state
//==========================================================================//
Device::Device(byte uPin, boolean invertedSwitching)
{
  pin = uPin;
  inverted = invertedSwitching;
  // set defaults
  byte status = STATUS_OFF;
  byte queuedStatus = STATUS_OFF;
}

// turn off device via relay
void Device::turnOff()
{
  inverted ? digitalWrite(pin, HIGH) : digitalWrite(pin, LOW);
  status = 0;
}

// turn on device via relay
void Device::turnOn()
{
  // support weird relay board from futurlec that switches on with logic 0
  inverted ? digitalWrite(pin, LOW) : digitalWrite(pin, HIGH);
  status = 1;
}

void Device::nextStatus()
{
  // no idea wtf is going on here. Need to come back to it
  if(queuedStatus == 49)
  {
    turnOn();
  }
  else if(queuedStatus == 48)
  {
    turnOff();
  }
}

void FacadeSensor::update(){}
void FacadeSensor::updateExternal(float input)
{
  _lastValue = input;
}

//==========================================================================//
// TMP36 Temperature sensor
//==========================================================================//

#define TEMP_VREF 5.0

TemperatureSensor::TemperatureSensor(byte uPin)
{
  pin = uPin;
}

//avarage a temperature and update _lastValue
void TemperatureSensor::update()
{
  float sum = 0;
  byte iterations = 6;
  for (byte i=0; i <= iterations; i++)
  {
     int reading = analogRead(pin);
     float voltage = reading * TEMP_VREF / 1024;
     sum +=  (voltage - 0.5) * 100;
     delay(10);
  }

  _lastValue = sum / iterations;
}


