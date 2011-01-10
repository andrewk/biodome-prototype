#ifndef Biodome_h
#define Biodome_h

#define STATUS_OFF 0
#define STATUS_ON 1

#include "WProgram.h"

//==========================================================================//
//  Device
//==========================================================================//
class Device
{ 	
  public:
	char * name;
	uint8_t status; // 0=off;1=on
  uint8_t queuedStatus; // 0=off;1=on
  byte pin;
	
	Device(byte pin);
	void turnOn();
	void turnOff();
  void nextStatus();
    
};

//==========================================================================//
// Sensor
//==========================================================================//
class Sensor 
{
    public:
      char * name;
		  virtual void update() {};
      inline void begin() {};
      inline float read() { return _lastValue;}; 
    protected:		
      float _lastValue;
};

//==========================================================================//
// Facade Sensor
//==========================================================================//
// Provide Sensor API to output from an external class or library
class FacadeSensor : public Sensor
{
  public:
    void update();
    void updateExternal(float input);
};
//==========================================================================// 
// TEMPERATURE sensor - TMP36
//==========================================================================//
class TemperatureSensor : public Sensor 
{
    public:
		  TemperatureSensor(byte pin);
      void update();
      byte pin;
};

//==========================================================================//
// Soil Moisture Sensor
//==========================================================================//
class SoilMoistureSensor : public Sensor
{
  public:
    SoilMoistureSensor(byte aPin, byte dPin);
    void update();
    byte aPin;
    byte dPin;
};

//==========================================================================// 
// LIGHT sensor - LDR
//==========================================================================//
class LightSensor : public Sensor 
{
    public:
		  LightSensor(byte aPin);
      void update();
      byte aPin;
};


#endif