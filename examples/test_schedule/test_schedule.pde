/**
 * REQUIRES: SDCard reader, RTC (DS1307),
 * SCHEDULE.TXT on sd card, one number (state) per line, for 24 lines
 */

#include <Wire.h>
#include <RTClib.h>
#include <SdFat.h>
#include <Biodome.h>

// STATES
#define NIGHT 1
#define SUNRISE 2
#define DAY 3
#define SUNSET 4

// Real Time Clock object
RTC_DS1307 RTC;

// SDCard
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;

int state;

// filename of log file on SD card
char syslog[13] = "SYSTEM00.CSV";

void setup()
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

  if (!file.close() || file.writeError)
  {
    Serial.println("e: close/write syslog");
  }

}

void loop()
{
  // read STATE from schedule file
  getStateFromSchedule();
  Environment env = getEnvironmentForState(state);

  // queue new Device status
  switch (state)
  {
    case NIGHT: 
      Serial.println("Night");
    break;

    case SUNRISE:
      Serial.println("Sunrise");
    break;

    case DAY:
      Serial.println("Day");
    break;

    case SUNSET:
      Serial.println("Sunset");
    break;
  }

  delay(3000);
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

void getStateFromSchedule()
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
     Serial.println("e: open schedule");
  }
  // move the file cursor to the desired point in the file
  if (file.seekSet(cursorPos))
  {
    file.read(tmp, 2);
  }
  // aaah crap. Formatting error in schedule file?
  else
  {
    Serial.print("CRITICAL ERROR: Cannot seek to position in schedule file: ");
    Serial.println(cursorPos);
  }

  if(!file.close())
  {
    Serial.println("e: open schedule");
  }

  // Understand byte arrays? I sure don't

  //Serial.println(tmp[1]);
  //char result = (char) tmp[1];
  //Serial.println(result);
  // ...yeah i dunno wtf I give up this works.
  state = tmp[1] - 48;
}
