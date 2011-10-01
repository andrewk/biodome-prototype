#ifndef Biodome_h
#define Biodome_h

#define STATUS_OFF 0
#define STATUS_ON 1

#include "WProgram.h"

//==========================================================================//
//  Environment
//==========================================================================//
struct Environment
{
  int target;
  int over;
  int extremeOver;
  int under;
};

//==========================================================================//
//  Device
//==========================================================================//
class Device
{
	public:
		char * name;
		uint8_t status; // 0=off;1=on
  	uint8_t queuedStatus; // 0=off;1=on
    int pin;
		boolean inverted;

		void configure(int outPin, boolean isControlInverted);
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
		void configure(char * sensorName, float measurementCompensation);
    inline void begin() {};
  	inline float read() { return _lastValue + _compensation;};
    protected:
  	float _lastValue;
		float _compensation;
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
// TEMPERATURE sensor - TMP36
//==========================================================================//
class LM335TemperatureSensor : public Sensor
{
	public:
		LM335TemperatureSensor(byte pin);
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
