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

#define COUNT_SENSORS 5
#define COUNT_DEVICES 5
#define LOOP_INTERVAL_MINUTES 5

// how many times we should iterate through the loop
// before logging the environment data to CSV
#define LOOPS_PER_LOG 2

// Real Time Clock object
RTC_DS1307 RTC;

// SDCard
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;

// set the LCD address to 0x27 for a 16 chars and 2 line display
LiquidCrystal_I2C lcd(0x27,16,2);

// State Machine
uint8_t * state;

// filename of log file on SD card
char syslog[13] = "SYSTEM00.CSV";

// count the loop, so we can only log data every X iterations
int loopCounter = 0;

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

void setup()
{
  Serial.begin(9600);
  Wire.begin();
  RTC.begin();
  dht_ambient.begin();
  dht_internal.begin();
  lcd.init();
  lcd.backlight();

  // Uncomment following line to sync RTC time to compile time
  //RTC.adjust(DateTime(__DATE__, __TIME__));
  if (!RTC.isrunning())
  {
      Serial.println("CRITICAL ERROR: RTC is NOT running");
  }

  // config devices
  PrimaryLight.configure(2, true);
  SecondaryLight.configure(3, true);
  Fans.configure(6, true);
  Heater.configure(7, true);
  FanBoost.configure(8, true);

  // config sensors
  TempMain.configure("Temperature", 0); // name, compensation
  HumidityMain.configure("Humidity", 0);
  HumidityAmbient.configure("Ambient Humidity", -5.0);
  TempAmbient.configure("Ambient Temp", -0.5);
  TempControlRoom.configure("Control Room Temp", 0); // name, pin, compensation

  // delay to give DHT sensors time to warm up (datasheet claims up to 30 seconds!)
  //delay(10000);
}

void loop()
{
  // measure execution time for more precise looping
  unsigned long milStart = millis();

  // read STATE from schedule file
  getStateFromSchedule();
  Environment env = getEnvironmentForState(state[1]);

  // queue new Device status
  switch (state[1])
  {
    case 1: // night
      PrimaryLight.queuedStatus = 0;
      SecondaryLight.queuedStatus = 0;
      lcd.print("Night      ");

    break;

    case 2: // sunrise
       PrimaryLight.queuedStatus = 0;
       SecondaryLight.queuedStatus = 1;
       lcd.print("Sunrise    ");
    break;

    case 3: // day
      PrimaryLight.queuedStatus = 1;
      SecondaryLight.queuedStatus = 1;
      lcd.print("Day        ");
    break;

    case 4: // sunset
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
  TempMain.updateExternal(dht_internal.readTemperature());
  HumidityMain.updateExternal(dht_internal.readHumidity());
  TempAmbient.updateExternal(dht_ambient.readTemperature());
  HumidityAmbient.updateExternal(dht_ambient.readHumidity());

  // process Device status overrides for Coolers and Heaters
  // set defaults for environmental controllers
  Fans.queuedStatus = 0;
  FanBoost.queuedStatus = 0;
  Heater.queuedStatus = 0;

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
  lcd.print("(");
  lcd.print(TempMain.read());
  lcd.print("c");
  // main humidity
  lcd.print(HumidityMain.read());
  lcd.print("%)(");
  // ambient
  lcd.print(TempAmbient.read());
  lcd.print("c");
  lcd.print(HumidityAmbient.read());
  lcd.print("%)");

  // write environment data to CSV
  if(loopCounter == 0 || loopCounter % LOOPS_PER_LOG == 0)
  {
    logSystemStatus();
    // ensure the loop counter doesn't get huge
    if(loopCounter = (20 * LOOPS_PER_LOG))
      loopCounter = 0;
  }

  // loop timing management
  loopCounter++;
  unsigned long execTime =  millis() - milStart;
  delay((LOOP_INTERVAL_MINUTES * 60000) - execTime);
}


Environment getEnvironmentForState(uint8_t state)
 {
    switch (state)
    {
      case 1:
        // night
        return (Environment) {
            24,
            2,
            6,
            2
        };
      break;

      case 2:
        // sunrise
        return (Environment) {
            24,
            2,
            4,
            4
        };
      break;

      case 3:
        // day
        return (Environment) {
            26,
            1,
            3,
            3
        };
      break;

      case 4:
        // sunset
        return (Environment) {
            26,
            3,
            5,
            3
        };
      break;
    }
}


void createAndOpenLogFile()
{
    // initialize the SD card
    if (!card.init()) Serial.println("e:card.init");
    if (!volume.init(card)) Serial.println("e:volume.init");
    if (!root.openRoot(volume)) Serial.println("e:openRoot");

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


uint8_t* getStateFromSchedule()
{
  DateTime now = RTC.now();
  int hour = (int)now.hour();

  // 2 chars per line, one for state, one line breakd
  int cursorPos = 2 * (hour-1);
  if (!file.open(root, "SCHEDULE.TXT", O_READ))
  {
     Serial.println("e: open schedule");
  }
  // move the file cursor to the desired point in the file
  file.seekSet(cursorPos);
  file.read(state, 1);
}


void logSystemStatus()
{
  file.writeError = false;
  if (!file.open(root, syslog, O_CREAT | O_APPEND | O_WRITE)) Serial.print("e: unable to open syslog");

  // Print timestamp
  writeTimestampToFile();

  // Write current state
  file.print(state[1]);
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
}
