#include <Arduino.h>
#include <NimBLEDevice.h>
#include "nimble/porting/nimble/include/nimble/nimble_port.h"
#include "inputs.h"

namespace {
constexpr char serviceId[] = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
constexpr char outputId[] = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
struct Button { uint8_t pin, slot; };
constexpr Button buttons[] = {{6, 1}, {8, 2}, {13, 3}, {14, 254}, {19, 255},
                              {36, 252}, {38, 251}, {42, 253}};
constexpr uint8_t volumePin = 1, motionPin = 4;
Keypad keypad;
MotionSensor motion;
VolumeSensor volume;
uint32_t lastAdc;
ble_npl_callout timer;
NimBLECharacteristic* output;
bool subscribed = false;

void send(const char* kind, unsigned value) {
  char line[16];
  int length = snprintf(line, sizeof(line), "%s:%u\n", kind, value);
  output->notify(reinterpret_cast<const uint8_t*>(line), length);
}

// Sample on the BLE host event queue so notifications, subscription changes,
// and disconnects run in order. Never queue or replay an old keypress.
void poll(ble_npl_event*) {
  if (!subscribed) return;
  const uint32_t now = millis();
  uint8_t mask = 0;
  for (unsigned i = 0; i < sizeof(buttons) / sizeof(buttons[0]); ++i) {
    if (digitalRead(buttons[i].pin) == HIGH) mask |= 1u << i;
  }
  const int key = keypad.sample(mask, now);
  if (key) send(key > 0 ? "BTN" : "REL", buttons[abs(key) - 1].slot);
  if (motion.sample(digitalRead(motionPin) == HIGH, now)) send("PIR", 1);
  if (now - lastAdc >= 50) {
    lastAdc = now;
    const int percent = volume.sample(analogRead(volumePin), now);
    if (percent >= 0) send("VOL", percent);
  }
  ble_npl_callout_reset(&timer, pdMS_TO_TICKS(5) ? pdMS_TO_TICKS(5) : 1);
}

void setSubscription(bool enabled) {
  if (enabled == subscribed) return;
  subscribed = enabled;
  if (!enabled) {
    ble_npl_callout_stop(&timer);
    return;
  }
  keypad = Keypad{};
  motion = MotionSensor{};
  volume = VolumeSensor{};
  lastAdc = millis();
  ble_npl_callout_reset(&timer, 1);
}

class Subscription : public NimBLECharacteristicCallbacks {
  void onSubscribe(NimBLECharacteristic*, ble_gap_conn_desc*, uint16_t flags) override {
    setSubscription((flags & 1u) != 0);
  }
} subscription;

class Connection : public NimBLEServerCallbacks {
  void onDisconnect(NimBLEServer*) override { setSubscription(false); }
} connection;
}  // namespace

void setup() {
  // Active-high modules drive these lines; disconnected inputs should read low.
  for (const auto& button : buttons) pinMode(button.pin, INPUT_PULLDOWN);
  pinMode(motionPin, INPUT_PULLDOWN);
  analogSetAttenuation(ADC_11db);
  analogReadResolution(12);
#ifdef RGB_BUILTIN
  neopixelWrite(RGB_BUILTIN, 0, 0, 0);
#endif
  NimBLEDevice::init("TapCall");
  ble_npl_callout_init(&timer, nimble_port_get_dflt_eventq(), poll, nullptr);
  auto* server = NimBLEDevice::createServer();
  server->setCallbacks(&connection, false);
  server->advertiseOnDisconnect(true);
  auto* service = server->createService(serviceId);
  output = service->createCharacteristic(outputId, NIMBLE_PROPERTY::NOTIFY);
  output->setCallbacks(&subscription);
  service->start();
  auto* advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(serviceId);
  advertising->setScanResponse(true);
  advertising->start();
}

void loop() { delay(1000); }
