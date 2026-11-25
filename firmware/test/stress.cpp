// Build on a desktop with the command in the repository README.
#include "../src/inputs.h"

#include <cassert>
#include <cstdio>
#include <random>
#include <vector>

struct KeyRig {
  Keypad keypad;
  std::mt19937 random{73241};
  uint32_t now = UINT32_MAX - 100;
  std::vector<int> events;

  // Jitter the poll interval between 1 and 9 ms, including a sample at entry.
  void hold(uint8_t mask, unsigned duration) {
    while (duration) {
      const int event = keypad.sample(mask, now);
      if (event) events.push_back(event);
      unsigned step = 1 + random() % 9;
      if (step > duration) step = duration;
      now += step;
      duration -= step;
    }
  }

  void expect(std::vector<int> wanted) {
    assert(events == wanted);
    events.clear();
  }
};

void stressKeys() {
  KeyRig rig;
  for (unsigned i = 0; i < 100000; ++i) {
    const int key = 1 + rig.random() % 8;
    const uint8_t mask = 1u << (key - 1);
    const uint8_t other = 1u << (key % 8);
    rig.hold(0, 70);
    rig.hold(mask, 5);
    rig.hold(0, 8);
    rig.hold(mask, 55);
    rig.hold(0, 20);  // Brief low on a held contact.
    rig.hold(mask, 70);
    rig.hold(mask | other, 50);  // A second key while the first is held.
    rig.hold(other, 50);
    rig.hold(0, 70);
    rig.expect({key, -key});

    // Overlapping keys before acceptance must suppress the whole gesture.
    rig.hold(mask, 10);
    rig.hold(mask | other, 60);
    rig.hold(other, 60);
    rig.hold(0, 70);
    rig.expect({});

    // The next distinct press, even on an adjacent key, remains usable.
    rig.hold(other, 60);
    rig.hold(0, 70);
    rig.expect({key % 8 + 1, -(key % 8 + 1)});
  }
}

void stressSessions() {
  KeyRig rig;
  for (int i = 0; i < 10000; ++i) {
    rig.hold(0, 60);
    rig.hold(1, 8);  // Subscription lost before the press settles.
    rig.keypad = Keypad{};
    rig.hold(1, 120);
    rig.hold(0, 20);
    rig.hold(1, 100);
    rig.hold(0, 70);
    rig.expect({});
    rig.hold(4, 70);
    rig.expect({3});
    rig.keypad = Keypad{};  // Disconnect after acceptance, before release.
    rig.hold(4, 70);
    rig.hold(0, 70);
    rig.expect({});
  }
}

void stressSensors() {
  MotionSensor motion;
  uint32_t now = UINT32_MAX - 1500;
  for (int i = 0; i < 10000; ++i) {
    assert(!motion.sample(true, now));
    assert(!motion.sample(true, now + 2999));
    assert(motion.sample(true, now + 3000));
    assert(!motion.sample(false, now + 3020));
    assert(!motion.sample(true, now + 3030));  // Glitch during continuous motion.
    assert(!motion.sample(true, now + 8030));
    assert(!motion.sample(false, now + 8050));
    assert(!motion.sample(false, now + 8250));
    now += 8300;
  }

  VolumeSensor volume;
  now = UINT32_MAX - 80;
  std::mt19937 random(1854);
  uint32_t lastReport = 0;
  for (int i = 0; i < 1000000; ++i, now += 50) {
    const int report = volume.sample(random() % 4096, now);
    if (report < 0) continue;
    assert(report <= 100);
    assert(lastReport == 0 || now - lastReport >= 200);
    lastReport = now;
  }
  VolumeSensor knob;
  assert(knob.sample(2048, 0) == -1);
  assert(knob.sample(2048, 50) == -1);
  assert(knob.sample(2048, 100) == 50);
  for (int i = 3; i < 3000; ++i) {
    assert(knob.sample(i % 3 == 0 ? 4095 : 2048, i * 50) == -1);
  }
  assert(knob.sample(0, 150000) == -1);
  assert(knob.sample(0, 150050) == 0);
  assert(knob.sample(4095, 150250) == -1);
  assert(knob.sample(4095, 150300) == 100);
}

int main() {
  stressKeys();
  stressSessions();
  stressSensors();
  std::puts("Passed 100000 gesture sequences, 10000 reconnect cycles, "
            "10000 motion cycles and 1000000 randomized ADC samples.");
}
