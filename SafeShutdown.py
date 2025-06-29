#!/usr/bin/env python3

# Import Device and set pin factory first
from gpiozero.pins.pigpio import PiGPIOFactory
from gpiozero import Device

# Force gpiozero to use pigpio globally
Device.pin_factory = PiGPIOFactory()

from gpiozero import Button, LED
from gpiozero.pins.pigpio import PiGPIOFactory
import os
from signal import pause
import subprocess

# Use pigpio factory
factory = PiGPIOFactory()

powerPin = 3
resetPin = 2
ledPin = 14
powerenPin = 4
hold = 1
led = LED(ledPin)
led.on()
power = LED(powerenPin)
power.on()

#functions that handle button events
def when_pressed():
    led.blink(on_time=0.2, off_time=0.2)  # Blink continuously

    output = int(subprocess.check_output(['/opt/RetroFlag/multi_switch.sh', '--es-pid']))
    if output:
        os.system("/opt/RetroFlag/multi_switch.sh --es-poweroff")
    else:
        os.system("sudo shutdown -h now")

def when_released():
 led.on()

import time
import threading

def stop_blink_after(seconds, led_obj):
    time.sleep(seconds)
    led_obj.off()
    led_obj.on()

def reboot():
    blink_time = 0.4  # 0.2s on + 0.2s off
    blink_count = 10
    total_blink_duration = blink_time * blink_count

    led.blink(on_time=0.2, off_time=0.2)  # Non-blocking infinite blink

    # Stop the blinking after total duration in a background thread
    threading.Thread(target=stop_blink_after, args=(total_blink_duration, led), daemon=True).start()

    output = int(subprocess.check_output(['/opt/RetroFlag/multi_switch.sh', '--es-pid']))
    output_rc = int(subprocess.check_output(['/opt/RetroFlag/multi_switch.sh', '--rc-pid']))

    if output_rc:
        os.system("/opt/RetroFlag/multi_switch.sh --closeemu")
    elif output:
        os.system("/opt/RetroFlag/multi_switch.sh --es-restart")
    else:
        os.system("sudo reboot")

btn = Button(powerPin, hold_time=hold)
rebootBtn = Button(resetPin)
rebootBtn.when_pressed = reboot
btn.when_pressed = when_pressed
btn.when_released = when_released
pause()
