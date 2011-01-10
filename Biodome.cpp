#include "WProgram.h"
#include "Biodome.h"


//==========================================================================//
// Model representation of a controlled relay with boolean state
//==========================================================================//
Device::Device(byte uPin) 
{
  pin = uPin;
  
  // set defaults
  byte status = STATUS_OFF;
  byte queuedStatus = STATUS_OFF;
}

// turn off device via relay
void Device::turnOff() 
{
  //Serial.println('turning OFF pin ');
  status = 0;
  digitalWrite(pin, LOW);
}

// turn on device via relay
void Device::turnOn() 
{
  //Serial.println(pin);
  digitalWrite(pin, HIGH);
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
  
/*
   int reading = analogRead(pin);  
   float voltage = reading * TEMP_VREF / 1024; 
   _lastValue = (voltage - 0.5) * 100 ;
*/
}

//==========================================================================//
// Soil Moisture Sensor - 5V across two nails in the soil. 
//   Digital pin sends voltage
//   Analog pin reads
//==========================================================================//
SoilMoistureSensor::SoilMoistureSensor(byte analogPin, byte digitalPin)
{
  aPin = analogPin;
  dPin = digitalPin;
  pinMode(dPin, OUTPUT);
}

void SoilMoistureSensor::update()
{
  digitalWrite(dPin, HIGH);
  _lastValue = analogRead(aPin);
  digitalWrite(dPin, LOW);
}

//==========================================================================//
// Light sensor - uses an LDR to give confirmation of light
//==========================================================================//

LightSensor::LightSensor(byte analogPin)
{
  aPin = analogPin;
}

void LightSensor::update()
{
  _lastValue = analogRead(aPin);
}
