#pragma once

#include <stdint.h>
#include <cstdlib>

// A gesture starts with one stable key and ends when all keys stay released.
// Use signed key numbers for press (+), release (-), or no event (0).
class Keypad {
 public:
  int sample(uint8_t mask, uint32_t now) {
    if (mask != lastMask_) {
      lastMask_ = mask;
      changedAt_ = now;
    }
    const uint32_t stable = now - changedAt_;
    if (mask == 0) {
      if (stable < 45) return 0;
      const int released = active_;
      active_ = 0;
      armed_ = true;
      candidate_ = 0;
      return -released;
    }
    if (!armed_) return 0;
    if ((mask & (mask - 1)) || (candidate_ && candidate_ != mask)) {
      armed_ = false;
      return 0;
    }
    candidate_ = mask;
    if (stable < 25) return 0;
    active_ = 1;
    while ((mask >>= 1) != 0) ++active_;
    armed_ = false;
    return active_;
  }

 private:
  uint8_t lastMask_ = 255;
  uint8_t candidate_ = 0;
  int active_ = 0;
  bool armed_ = false;
  uint32_t changedAt_ = 0;
};

class MotionSensor {
 public:
  bool sample(bool high, uint32_t now) {
    if (high != high_) {
      high_ = high;
      changedAt_ = now;
    }
    const uint32_t stable = now - changedAt_;
    if (!high && stable >= 200) reported_ = false;
    if (!high || reported_ || stable < 3000) return false;
    reported_ = true;
    return true;
  }

 private:
  bool high_ = false;
  bool reported_ = false;
  uint32_t changedAt_ = 0;
};

class VolumeSensor {
 public:
  // Called every 50 ms. A median of three rejects isolated ADC spikes.
  int sample(int adc, uint32_t now) {
    const int value = (adc * 100 + 2047) / 4095;
    if (!samples_) previous_ = older_ = value;
    const int median = value < previous_
        ? clamp(older_, value, previous_) : clamp(older_, previous_, value);
    older_ = previous_;
    previous_ = value;
    if (samples_ < 3) ++samples_;
    if (samples_ < 3) return -1;
    if (last_ >= 0 && now - sentAt_ < 200) return -1;
    if (median == last_) return -1;
    const bool endpoint = median == 0 || median == 100;
    if (last_ >= 0 && !endpoint && std::abs(median - last_) < 3) return -1;
    last_ = median;
    sentAt_ = now;
    return median;
  }

 private:
  static int clamp(int v, int low, int high) {
    return v < low ? low : (v > high ? high : v);
  }
  int previous_ = 0, older_ = 0, last_ = -1;
  unsigned samples_ = 0;
  uint32_t sentAt_ = 0;
};
