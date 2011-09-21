#include "WProgram.h"
#include "Biodome.h"


//==========================================================================//
// Model representation of a controlled relay with boolean state
//==========================================================================//

void Device::configure(char * deviceName, byte outPin, boolean isControlInverted)
{
	char * name = deviceName;
	byte pin = outPin;
	pinMode(pin, OUTPUT);
	boolean inverted = isControlInverted;

	// set defaults
  	byte status = STATUS_OFF;
  	byte queuedStatus = STATUS_OFF;
}

// turn off device via relay
void Device::turnOff()
{
  inverted ? digitalWrite(pin, HIGH) : digitalWrite(pin, LOW);
  status = STATUS_OFF;
}

// turn on device via relay
void Device::turnOn()
{
  // support weird relay board from futurlec that switches on with logic 0
  inverted ? digitalWrite(pin, LOW) : digitalWrite(pin, HIGH);
  status = STATUS_ON;
}

void Device::nextStatus()
{
  if(queuedStatus == STATUS_ON)
  {
    turnOn();
  }
  else if(queuedStatus == STATUS_OFF)
  {
    turnOff();
  }
}

void Sensor::configure(char * sensorName, float measurementCompensation)
{
	char * name = sensorName;
	float _compensation = measurementCompensation;
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


//==========================================================================//
// LM335 Temperature sensor
//==========================================================================//

LM335TemperatureSensor::LM335TemperatureSensor(byte uPin)
{
	pin = uPin;
}

//avarage a temperature and update _lastValue
void LM335TemperatureSensor::update()
{
	float val = 0;
	float val2 = 0;
	float deg = 0;
	float celcius = 0;

	val = analogRead(pin); // read value from the sensor
	val2 = val * 0.00489; // take SENSOR value and multiply it by 4.89mV
	deg = val2 * 100; // multiply by 100 to get degrees in K

	_lastValue = deg - 273.15; // subtract absolute zero to get degrees celcius

}

