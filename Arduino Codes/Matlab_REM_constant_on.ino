#include <stdlib.h>
#include <SPI.h>

#define SERIAL_BAUD_RATE 9600

boolean flag = true;
char terminator = '/';
String mode;

void setup() {
  // put your setup code here, to run once:
  Serial.begin(SERIAL_BAUD_RATE);
  pinMode(13, OUTPUT);
}

void loop() {
  // put your main code here, to run repeatedly:
  if (Serial.available())  {
    if (flag) {
      mode = Serial.readStringUntil(terminator);  //set mode

      if (mode == "on") {
        digitalWrite(13, HIGH);
        delay(10);
      }

      if (mode == "off") {
        digitalWrite(13, LOW);
        delay(10);
      }
      flag = false;
    }
    if (Serial.available())  {
      char tem = Serial.read();   //gets one byte from serial buffer
      if (tem == '\n') {
        flag = true;           //maintain lights mode until next command( avoid flashing)
      }
    }
  }
}
