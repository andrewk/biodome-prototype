#include <Wire.h>
#include <RTClib.h>
#include <SdFat.h>
#include <Biodome.h> 
#include <Sensirion.h>

/**************************
   -==Seedling Factory==-
   Assisted environment for
     starting seedlings
 **************************/

#define COUNT_SENSORS 3
#define COUNT_DEVICES 2
#define LOOP_INTERVAL_MINUTES 5 
#define LOOPS_PER_LOG 2  // how many times we should iterate through the loop before logging the environment data to CSV

//---------------
// Devices
Device Light(6); 
Device CirculationFan(7);
Device *Devices[] = {&Light, &CirculationFan};

//----------------------
// Sensors
FacadeSensor TempMain;
FacadeSensor Humidity;
FacadeSensor DewPoint;
Sensor *Sensors[COUNT_SENSORS] = {&TempMain, &Humidity, &DewPoint};

Sensirion sht = Sensirion(8, 9);
float sht_temp;
float sht_humidity;
float sht_dewpoint;

RTC_DS1307 RTC; //  Real Time Clock object

// SDCard
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;

char syslog[13] = "SYSTEM00.CSV"; // filename for system log CSV file, 8.3 filename
char eventlog[13] = "EVENTS00.CSV";
int loopCounter = 0; // count the loop, so we can only log data every X iterations

//---------------------------------------------------------------
void setup() 
//---------------------------------------------------------------
{  
  Serial.begin(9600);
  Wire.begin();
  RTC.begin();
  
  // Uncomment following line to sync RTC time to compile time
  //RTC.adjust(DateTime(__DATE__, __TIME__));
  
  if (!RTC.isrunning()) 
  {
    Serial.println("CRITICAL ERROR: RTC is NOT running");
  }
  
  // CONFIG DEVICES
  Light.name = "Lights";  
  CirculationFan.name = "Circulation Fans";
  pinMode(Light.pin, OUTPUT);  
  pinMode(CirculationFan.pin, OUTPUT);

  // CONFIG SENSORS 
  //TempExternal.name = "External Temp";
  //TempSoil.name = "Soil Temp";
  TempMain.name = "Air Temp";
  Humidity.name = "Humidity";
  DewPoint.name = "Dew Point";
  

  // allow system report to be requested at any time via serial
  // FIXME: buggy. Currently disabled 
  // attachInterrupt(0, reportToSerial, RISING);

  // initialize the SD card
  if (!card.init()) Serial.println("e:card.init");
  if (!volume.init(card)) Serial.println("e:volume.init");
  if (!root.openRoot(volume)) Serial.println("e:openRoot");

  // open/create System Log CSV file, new file for each time arduino is restarted to try and avoid data corruption
  for (uint8_t i = 0; i < 100; i++) 
  {
    syslog[6] = i/10 + '0';
    syslog[7] = i%10 + '0';
    if (file.open(root, syslog, O_CREAT | O_EXCL | O_WRITE)) 
    {
      break; 
    }
  }
  
  if (!file.isOpen()) 
  {
    Serial.println("CRITICAL ERROR: Failed to create syslog file");
  }
  // add column headers
  file.print("Timestamp");
  file.print(", ");
  file.print("Time");
  file.print(", ");
  for (byte i = 0; i < COUNT_SENSORS; i++) 
  {
    file.print(Sensors[i]->name);
    file.print(", ");
  }  
  for (byte i = 0; i < COUNT_DEVICES; i++) 
  {
    file.print(Devices[i]->name);
    file.print(", ");
  }
  file.println("");
  if (!file.close() || file.writeError)  
  {
    Serial.println("e: close/write syslog");
  }

  // open/create Event Log CSV file, new file for each time arduino is restarted to try and avoid data corruption
  for (uint8_t i = 0; i < 100; i++) 
  {
    eventlog[6] = i/10 + '0';
    eventlog[7] = i%10 + '0';
    if (file.open(root, eventlog, O_CREAT | O_EXCL | O_WRITE)) break;
  }
  if (!file.isOpen()) 
  {
    Serial.println("CRITICAL ERROR: Failed to create eventlog file");
  }
  // Write headers to CSV file
  file.print("Timestamp");
  file.print(", ");
  file.print("Time");
  file.print(", ");
  file.print("Device");
  file.print(", ");
  file.print("Next Status");
  file.print(", ");
  file.print("Sensor");
  file.print(", ");
  file.print("Sensor Output");
  file.println(", ");

  file.close();
}

//---------------------------------------------------------------
void loop() 
//---------------------------------------------------------------
{
  // measure execution time for more precise looping
  unsigned long milStart = millis();
  
  // calculate environment data (temperature, humidity etc)
  for (byte i = 0; i < COUNT_SENSORS; i++) 
  {
    Sensors[i]->update();
  }

  // populate facade sensors
  sht.measure(&sht_temp, &sht_humidity, &sht_dewpoint);
  TempMain.updateExternal(sht_temp);
  Humidity.updateExternal(sht_humidity);
  DewPoint.updateExternal(sht_dewpoint);
  
  //---------------------------------------------------------------
  // read schedule text file and parse Device states for this hour
  // the schedule file must be 24 lines long, one line for each hour of the day starting at 00 and ending at 23
  // the format of the file is the state of each device in the order they are declared in the Devices array. eg:
  // 110
  // 010
  // The above would instruct that at 12am, the first two devices should be turned on and the third should be turned off, 
  // then at 1am, the first and third devices should be turned off, and the second device should be turned on
  //---------------------------------------------------------------
  
  DateTime now = RTC.now();
  int hour = (int)now.hour();

  uint8_t instructions[COUNT_DEVICES];
  int cursorPos = (COUNT_DEVICES+1) * (hour-1) ;
  if (!file.open(root, "SCHEDULE.TXT", O_READ))
  { 
     Serial.println("e: open schedule");
  }
  // move the file cursor to the desired point in the file
  if (file.seekSet(cursorPos))
  {
    file.read(instructions, COUNT_DEVICES); 
  }
  // aaah crap. Formatting error in schedule file?
  else
  {
    Serial.print("CRITICAL ERROR: Cannot seek to position in schedule file: ");
    Serial.println(cursorPos);
  }
  file.close(); 
  
  //-----------------------------------
  // SCHEDULING
  //
  // iterate through Devices, turning them on or off according to their schedule
  for (byte ic = 0; ic < COUNT_DEVICES; ic++) 
  {
    Devices[ic]->queuedStatus = (int)instructions[ic]; 
  }

  //-----------------------------------
  // SENSOR OVERIDES
  //
  // Lights turn off if grow space gets too hot
  sensorOverride(&Light, TempMain, -1, 45, true); //-1 means ignore
  
  //Fans turn on if humidity too high
  sensorOverride(&CirculationFan, Humidity, -1, 87, false);
  
  //Fans turn on if temp too high
  sensorOverride(&CirculationFan, TempMain, 20, -1, true);
  

  // iterate through Devices, enable queued status
  // this is done to minimize relay switching in the cases where a sensor override
  // event causes a different status than scheduled
  for (byte ic = 0; ic < COUNT_DEVICES; ic++) 
  {
    Devices[ic]->nextStatus(); 
  }

  // log system
  if(loopCounter == 0 || loopCounter % LOOPS_PER_LOG == 0)
  {
    logSystemStatus();
    // ensure the loop counter doesn't get huge
    if(loopCounter = (20 * LOOPS_PER_LOG))
      loopCounter = 0;
  }
  
  loopCounter++;
 
  unsigned long execTime =  millis() - milStart;
  delay((LOOP_INTERVAL_MINUTES * 60000) - execTime);
}

/**
 * IGNORES -1 
 * setting minValue or maxValue to -1 will cause the override funciton to skip that value
 */
void sensorOverride(Device* dev, Sensor sensor, float minValue, float maxValue, boolean invert)
{
  if(sensor.read() > maxValue && maxValue != -1)
  {
    dev->queuedStatus = invert ? 0 : 1;  
    logOverrideEvent(dev, sensor);
  }
  else if (sensor.read() < minValue && minValue != -1)
  {
    dev->queuedStatus = invert ? 1 : 0; 
    logOverrideEvent(dev, sensor);
  }
}

void logSystemStatus()
{  
  file.writeError = false;
  if (!file.open(root, syslog, O_CREAT | O_APPEND | O_WRITE)) Serial.print("e: unable to open syslog");

  // Print timestamp
  writeTimestampToFile();

  // Log Sensors first
  for (byte i = 0; i < COUNT_SENSORS; i++) 
  {
    file.print(Sensors[i]->read());
    file.print(", ");
  }  

  // Log Devices
  for (byte i = 0; i < COUNT_DEVICES; i++) 
  {
    file.print(Devices[i]->status);
    file.print(", ");
  }
  file.println("");
  if (!file.close() || file.writeError) 
  {
    Serial.println("e: close/write syslog");
  }
}

void logOverrideEvent(Device* device, Sensor sensor)
{
  // open Event Log CSV file
  file.writeError = false;
  if (!file.open(root, eventlog, O_CREAT | O_APPEND | O_WRITE)) Serial.print("e: unable to open eventlog");

  // Print timestamp
  writeTimestampToFile();
  file.print(device->name);
  file.print(", ");
  file.print(device->queuedStatus, DEC);
  file.print(", ");
  file.print(sensor.name);
  file.print(", ");
  file.print(sensor.read(), DEC);
  file.println(", ");
  if (!file.close() || file.writeError){
    Serial.print("e: close/write eventlog");
  }
}

// FIXME
// Interupt Event
// Allows device to receive system stats without interrupting logging or scheduling
void reportToSerial()
{
  // Log Sensors first
  Serial.println("SENSORS");
  for (byte i = 0; i < COUNT_SENSORS; i++) 
  {
    Serial.print(Sensors[i]->name);
    Serial.print(":");
    serialPrintFloat(Sensors[i]->read());
    Serial.println("");
  } 

  // Log Devices
  Serial.println("DEVICES");
  for (byte i = 0; i < COUNT_DEVICES; i++) 
  {
    Serial.print(Devices[i]->name);
    Serial.print(":");
    Serial.println(Devices[i]->status, DEC);
  }  
}

// Helper function for inserting both UNIX timestamp and 
// human-readable forms of current time in CSV format
// uses "file" global var to save 300 bytes in binary size
void writeTimestampToFile()
{
  DateTime now = RTC.now();
  file.print(now.unixtime());
  file.print(", ");
  file.print(now.year(), DEC);
  file.print("/");
  file.print(now.month(), DEC);
  file.print("/");
  file.print(now.day(), DEC);
  file.print(" ");
  file.print(now.hour(), DEC);
  file.print(":");
  file.print(now.minute(), DEC);
  file.print(":");
  file.print(now.second(), DEC);
  file.print(", ");  
}

void serialPrintFloat(float f)
{
  Serial.print((int)f);
  Serial.print(".");
  int decplace = (f - (int)f) * 100;
  Serial.print(abs(decplace));
}

