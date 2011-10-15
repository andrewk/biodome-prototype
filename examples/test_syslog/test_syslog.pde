#include <Wire.h>
#include <SdFat.h>
#include <Biodome.h>

// Configuration
#define LOOP_INTERVAL_MINUTES 1

// how many times we should iterate through the loop
// before logging the environment data to CSV
#define LOOPS_PER_LOG 2

// SDCard
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;

// filename of log file on SD card
char syslog[13] = "SYSTST00.CSV";

// count the loop, so we can only log data every X iterations
int loopCounter = 0;

// program has crashed in an unrecoverable way, abort.
boolean abortExec = false;

void fatalError(char * msg)
{
  abortExec = true;
  Serial.print("FATAL: ");
  Serial.println(msg);
}

void setup()
{
  Serial.begin(9600);
  Wire.begin();
  initDataAndCreateLogFile();
}

void loop()
{
  // infinite loop if the program has crashed
  if(abortExec) return;

  // measure execution time for more precise looping
  unsigned long milStart = millis();

  // write environment data to CSV
  if(loopCounter == 0 || loopCounter % LOOPS_PER_LOG == 0)
  {
    file.writeError = false;
    if (!file.open(root, syslog, O_CREAT | O_APPEND | O_WRITE)) fatalError("open syslog");

    file.print("1");
    file.print(", ");
    file.println("");

    if (!file.close() || file.writeError)
    {
      fatalError("close/write syslog");
    }

    // ensure the loop counter doesn't get huge
    if(loopCounter = (20 * LOOPS_PER_LOG)) loopCounter = 0;
  }

  // loop timing management
  loopCounter++;
  delay((LOOP_INTERVAL_MINUTES * 6000) - (millis() - milStart)); //made 10x faster for testing
}


void initDataAndCreateLogFile()
{
 // file.writeError = false;

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
    fatalError("Create syslog");
  }
  // add column headers
  file.print("State");
  file.println("");

  if (!file.close() || file.writeError)
  {
    fatalError("close/write syslog");
  }


}

