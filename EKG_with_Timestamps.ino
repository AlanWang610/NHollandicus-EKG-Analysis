const int heartPin = A1; // we'll be connecting the analog output on A0 to the monitor
unsigned long time; // declare a time tracker
int heartValue;
void setup() {
  // transmission at 115200 bits/s
  Serial.begin(115200);
  Serial.println("Starting EKG with Timestamps");
}
void loop() {
  heartRate();
  showTime();
  delay(1);
}

void heartRate() {
  heartValue = analogRead(heartPin);
  String stringHeart = String(heartValue);
  String displayHeart = stringHeart;
  Serial.println(displayHeart);
}
void showTime() {
  time = millis();
  String stringTime = String(time);
  String displayTime = stringTime + " ";
  Serial.print(displayTime);
}
