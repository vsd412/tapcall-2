#include <Arduino.h>
#include <NimBLEDevice.h>

namespace {
constexpr char serviceId[] = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
constexpr char outputId[] = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
NimBLECharacteristic* output;

struct Button {
  Button(uint8_t pin, uint8_t slot) : pin(pin), slot(slot) {}
  uint8_t pin;
  uint8_t slot;
  bool raw = false;
  bool pressed = false;
  uint32_t changed = 0;
};

// Active-high button modules, in the original board's wiring order.
Button buttons[] = {{6, 1}, {8, 2}, {13, 3}, {14, 254}, {19, 255},
                    {36, 252}, {38, 251}, {42, 253}};
constexpr uint8_t volumePin = 1;
constexpr uint8_t motionPin = 4;
int lastVolume;
uint32_t volumeSample = 0;
uint32_t motionStart = 0;
bool motionHigh = false;
bool motionReported = false;

void send(const char* kind, unsigned value) {
  if (!output->getSubscribedCount()) return;
  char line[16];
  snprintf(line, sizeof(line), "%s:%u\n", kind, value);
  output->setValue(line);
  output->notify();
}

void pollButtons(uint32_t now) {
  for (auto& b : buttons) {
    bool raw = digitalRead(b.pin) == HIGH;
    if (raw != b.raw) {
      b.raw = raw;
      b.changed = now;
    }
    if (raw != b.pressed && now - b.changed >= (raw ? 10u : 15u)) {
      b.pressed = raw;
      send(raw ? "BTN" : "REL", b.slot);
    }
  }
}

int readVolume() { return (analogRead(volumePin) * 100 + 2047) / 4095; }

void pollSensors(uint32_t now) {
  if (now - volumeSample >= 50) {
    volumeSample = now;
    int value = readVolume();
    if (abs(value - lastVolume) > 2) {
      lastVolume = value;
      send("VOL", value);
    }
  }
  bool high = digitalRead(motionPin) == HIGH;
  if (high && !motionHigh) {
    motionStart = now;
    motionReported = false;
  }
  if (high && !motionReported && now - motionStart >= 3000) {
    motionReported = true;
    send("PIR", 1);
  }
  motionHigh = high;
}
}  // namespace

void setup() {
  for (auto& b : buttons) {
    pinMode(b.pin, INPUT_PULLUP);
    b.pressed = b.raw = digitalRead(b.pin) == HIGH;
  }
  pinMode(motionPin, INPUT);
  analogSetAttenuation(ADC_11db);
  analogReadResolution(12);
  lastVolume = readVolume();
#ifdef RGB_BUILTIN
  neopixelWrite(RGB_BUILTIN, 0, 0, 0);
#endif
  NimBLEDevice::init("TapCall");
  auto* server = NimBLEDevice::createServer();
  server->advertiseOnDisconnect(true);
  auto* service = server->createService(serviceId);
  output = service->createCharacteristic(outputId, NIMBLE_PROPERTY::NOTIFY);
  service->start();
  auto* advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(serviceId);
  advertising->setScanResponse(true);
  advertising->start();
}

void loop() {
  const auto now = millis();
  pollButtons(now);
  pollSensors(now);
  delay(2);
}
