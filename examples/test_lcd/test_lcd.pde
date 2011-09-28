// Uses dfrobot.com I2C LCD library
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

LiquidCrystal_I2C lcd(0x27,16,2);  // set the LCD address to 0x27 for a 16 chars and 2 line display

void setup()
{
  lcd.init();                      // initialize the lcd 
  lcd.backlight();
  lcd.print("Sunset     ");
  lcd.print("11:11");
  lcd.setCursor(0, 1);
  lcd.print("(25c");
  lcd.print("60%)(25c70%)");
}

void loop()
{
}
