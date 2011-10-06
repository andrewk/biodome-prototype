#include <Wire.h>
#include <RTClib.h>
#include <SdFat.h>
#include <DHT.h>
#include <Biodome.h>
#include <LiquidCrystal_I2C.h>

// STATES
#define NIGHT 1
#define SUNRISE 2
#define DAY 3
#define SUNSET 4

// Configuration
#define COUNT_SENSORS 5
#define COUNT_DEVICES 5
#define LOOP_INTERVAL_MINUTES 5
#define REPORT_ERRORS_TO_LCD true
#define FAN_POWER_DETECTION_PIN 12

// how many times we should iterate through the loop
// before logging the environment data to CSV
#define LOOPS_PER_LOG 2

// Devices
Device PrimaryLight;
Device SecondaryLight;
Device Fans;
Device Heater;
Device FanBoost;
Device * Devices[] = { &PrimaryLight, &SecondaryLight, &Fans, &Heater, &FanBoost };

// Sensors
TemperatureSensor TempControlRoom(0);
FacadeSensor TempMain;
FacadeSensor HumidityMain;
FacadeSensor TempAmbient;
FacadeSensor HumidityAmbient;
Sensor * Sensors[] = { &TempMain, &HumidityMain, &TempAmbient, &HumidityAmbient, &TempControlRoom};

// DHT temp/humidity sensors (DHT lib)
DHT dht_ambient(1, DHT22);
DHT dht_internal(2, DHT22);

// Real Time Clock object
RTC_DS1307 RTC;

// SDCard
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;

// set the LCD address to 0x27 for a 16 chars and 2 line display
LiquidCrystal_I2C lcd(0x27,16,2);

// filename of log file on SD card
char syslog[13] = "SYSTEM00.CSV";

// count the loop, so we can only log data every X iterations
int loopCounter = 0;

// program has crashed in an unrecoverable way, abort.
boolean abortExec = false;

void fatalError(char * msg)
{
  abortExec = true;
  Serial.print("FATAL: ");
  Serial.println(msg);

  // shut it down
  for (byte ic = 0; ic < COUNT_DEVICES; ic++)
  {
    Devices[ic]->turnOff();
  }

  if(REPORT_ERRORS_TO_LCD)
  {
    lcd.clear();
    lcd.print("E:");
    lcd.print(msg);
  }
}

void setup()
{
  Serial.begin(9600);
  Wire.begin();
  RTC.begin();
  dht_ambient.begin();
  dht_internal.begin();
  lcd.init();
  lcd.backlight();
  pinMode(FAN_POWER_DETECTION_PIN, INPUT);

  // config devices
  PrimaryLight.configure(2, true);
  SecondaryLight.configure(3, true);
  FanBoost.configure(4, true);
  Heater.configure(5, true);
  Fans.configure(6, true);

  // config sensors
  TempMain.configure("Temperature", 0); // name, compensation
  HumidityMain.configure("Humidity", 0);
  HumidityAmbient.configure("Ambient Humidity", -5.0);
  TempAmbient.configure("Ambient Temp", -0.5);
  TempControlRoom.configure("Control Room Temp", 0); // name, pin, compensation

  // Uncomment following line to sync RTC time to compile time
  //RTC.adjust(DateTime(__DATE__, __TIME__));
  if (!RTC.isrunning())
  {
      fatalError("RTC is NOT running");
  }

  initDataAndCreateLogFile();

  // delay to give DHT sensors time to warm up (datasheet claims up to 30 seconds!)
  delay(10000);
}

void loop()
{
  checkFanPower();

  // infinite loop if the program has crashed
  if(abortExec) return;

  // measure execution time for more precise looping
  unsigned long milStart = millis();

  // read STATE from schedule file
  // system state
  int state = getStateFromSchedule();
  Environment env = getEnvironmentForState(state);
  if(abortExec) return;

  // queue new Device status
  switch (state)
  {
    case NIGHT: // night
      PrimaryLight.queuedStatus = 0;
      SecondaryLight.queuedStatus = 0;
      lcd.print("Night      ");

    break;

    case SUNRISE:
      PrimaryLight.queuedStatus = 0;
      SecondaryLight.queuedStatus = 1;
      lcd.print("Sunrise    ");
    break;

    case DAY:
      PrimaryLight.queuedStatus = 1;
      SecondaryLight.queuedStatus = 1;
      lcd.print("Day        ");
    break;

    case SUNSET:
      PrimaryLight.queuedStatus = 0;
      SecondaryLight.queuedStatus = 0;
      lcd.print("Sunset     ");
    break;
  }

  // update sensors
  for (byte i = 0; i < COUNT_SENSORS; i++)
  {
    Sensors[i]->update();
  }

  // populate facade sensors
  /*
  TempMain.updateExternal(dht_internal.readTemperature());
  HumidityMain.updateExternal(dht_internal.readHumidity());
  TempAmbient.updateExternal(dht_ambient.readTemperature());
  HumidityAmbient.updateExternal(dht_ambient.readHumidity());
  */

  TempMain.updateExternal(28.90);
  HumidityMain.updateExternal(34.98);
  TempAmbient.updateExternal(24.21);
  HumidityAmbient.updateExternal(61.43);


  // process Device status overrides for Coolers and Heaters
  // set defaults for environmental controllers
  Fans.queuedStatus = 0;
  FanBoost.queuedStatus = 0;
  Heater.queuedStatus = 0;

  // temp of zero means DHT22 sensor failed.
  // dont make temp compensation decisions with a failed sensor
  if(TempMain.read() != 0)
  {
    // WAY too hot
    if (TempMain.read() >= env.extremeOver)
    {
      Fans.queuedStatus = 1;
      FanBoost.queuedStatus = 1;
    }
    // too hot
    else if (TempMain.read() >= env.over)
    {
      Fans.queuedStatus = 1;
    }
    else if (TempMain.read() >= env.extremeOver)
    {
      Heater.queuedStatus = 1;
    }
  }

  // iterate through Devices, enable queued status
  // this is done to minimize relay switching in the cases where a sensor override
  // event causes a different status than scheduled
  for (byte ic = 0; ic < COUNT_DEVICES; ic++)
  {
    Devices[ic]->nextStatus();
  }

  // finish updating LCD
  DateTime now = RTC.now();
  lcd.print(now.hour(), DEC);
  lcd.print(":");
  lcd.print(now.minute(), DEC);
  // second line
  lcd.setCursor(0, 1);
  // main temp
  lcd.print((int)TempMain.read());
  lcd.print("c");
  // main humidity
  lcd.print((int)HumidityMain.read());
  lcd.print("% vs ");
  // ambient
  lcd.print((int)TempAmbient.read());
  lcd.print("c");
  lcd.print((int)HumidityAmbient.read());
  lcd.print("% ");

  // write environment data to CSV
  if(loopCounter == 0 || loopCounter % LOOPS_PER_LOG == 0)
  {
    file.writeError = false;
    if (!file.open(root, syslog, O_CREAT | O_APPEND | O_WRITE)) Serial.print("e: unable to open syslog");

    // Print timestamp
    writeTimestampToFile();

    // Write current state
    file.print(state);
    file.print(", ");

    // Log Sensors first
    for (byte i = 0; i < COUNT_SENSORS; i++)
    {
      file.print(Sensors[i]->read());
      file.print(", ");
    }

    file.println("");
    if (!file.close() || file.writeError)
    {
      Serial.println("e: close/write syslog");
    }

    // ensure the loop counter doesn't get huge
    if(loopCounter = (20 * LOOPS_PER_LOG))
      loopCounter = 0;
  }

  // loop timing management
  loopCounter++;
  delay((LOOP_INTERVAL_MINUTES * 60000) - (millis() - milStart));
}


Environment getEnvironmentForState(int state)
{
  switch (state)
  {
    case NIGHT:
      return (Environment) {
        24,
          2,
          6,
          2
      };
      break;

    case SUNRISE:
      return (Environment) {
        24,
          2,
          4,
          4
      };
      break;

    case DAY:
      return (Environment) {
        26,
          1,
          3,
          3
      };
      break;

    case SUNSET:
      return (Environment) {
        26,
          3,
          5,
          3
      };
      break;

    case 0: // reading state failed
      fatalError("Invalid State: 0");
      break;
    default : // reading state REALLY messed up
      fatalError("Invalid State");
      break;
  }
}

void initDataAndCreateLogFile()
{
  // initialize the SD card
  if (!card.init()) fatalError("card.init");
  if (!volume.init(card)) fatalError("volume.init");
  if (!root.openRoot(volume)) fatalError("SD card open dir");
  if (abortExec) return;

  // open/create System Log CSV file, new file for each time arduino is restarted to try and avoid data corruption
  for (uint8_t i = 0; i < 100; i++)
  {
    syslog[6] = i / 10 + '0';
    syslog[7] = i % 10 + '0';
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
  file.print("timestamp, ");
  file.print("time, ");
  file.print("state, ");
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
}

/**
 * Helper function for inserting both UNIX timestamp and
 * human-readable forms of current time in CSV format
 * uses "file" global var to save 300 bytes in binary size
 */
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


int getStateFromSchedule()
{
  uint8_t tmp[1]; // temp store for state
  DateTime now = RTC.now();
  int hour = (int)now.hour();

  //Serial.print("hour: ");
  //Serial.println(hour);

  // 2 chars per line, one for state, one line breakd
  int cursorPos = (2 * hour) - 1;
  if (!file.open(root, "SCHEDULE.TXT", O_READ))
  {
    fatalError("Can't open schedule");
  }
  // move the file cursor to the desired point in the file
  if (file.seekSet(cursorPos))
  {
    file.read(tmp, 2);
  }
  // aaah crap. Formatting error in schedule file?
  else
  {
    fatalError("Corrupt schedule");
  }
  file.close();

  //-----------
  // Understand byte arrays? I sure don't
  //-----------
  //Serial.println(tmp[1]);
  //char result = (char) tmp[1];
  //Serial.println(result);
  // ...yeah i dunno wtf I give up this works.
  return tmp[1] - 48;
}

void checkFanPower()
{
  if(digitalRead(FAN_POWER_DETECTION_PIN) == LOW))
  {
    fatalError("Exhaust fan power");
  }
}
