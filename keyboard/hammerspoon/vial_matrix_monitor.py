#!/usr/bin/env python3

import time

import hid

VENDOR_ID = 0xBEEB
PRODUCT_ID = 0x0002
RAW_USAGE_PAGE = 0xFF60
RAW_USAGE = 0x61
ROWS = 8
COLS = 6
REPORT_SIZE = 32
POLL_INTERVAL = 0.02


def find_device():
    return next(
        (
            device
            for device in hid.enumerate(VENDOR_ID, PRODUCT_ID)
            if device["usage_page"] == RAW_USAGE_PAGE
            and device["usage"] == RAW_USAGE
        ),
        None,
    )


def send_command(device, payload):
    request = bytes([0, *payload] + [0] * (REPORT_SIZE - len(payload)))
    if device.write(request) != REPORT_SIZE + 1:
        raise OSError("short Vial HID write")

    response = bytes(device.read(REPORT_SIZE, 500))
    if len(response) != REPORT_SIZE:
        raise OSError("invalid Vial HID response")
    return response


def read_pressed(device):
    response = send_command(device, [0x02, 0x03])
    if response[:2] != bytes([0x02, 0x03]):
        raise OSError("invalid Vial matrix response")

    pressed = []
    row_size = (COLS + 7) // 8
    for row in range(ROWS):
        row_data = response[2 + row * row_size : 2 + (row + 1) * row_size]
        for col in range(COLS):
            byte_index = len(row_data) - 1 - col // 8
            if (row_data[byte_index] >> (col % 8)) & 1:
                pressed.append(f"{row},{col}")
    return pressed


def read_unlock_status(device):
    return send_command(device, [0xFE, 0x05])[0] == 1


def emit(pressed):
    state = ";".join(pressed) if pressed else "-"
    print(f"STATE {state}", flush=True)


def main():
    previous = None
    while True:
        descriptor = find_device()
        if descriptor is None:
            if previous != []:
                emit([])
                previous = []
            time.sleep(1)
            continue

        device = hid.device()
        try:
            device.open_path(descriptor["path"])
            status = "UNLOCKED" if read_unlock_status(device) else "LOCKED"
            print(f"STATUS {status}", flush=True)
            while True:
                pressed = read_pressed(device)
                if pressed != previous:
                    emit(pressed)
                    previous = pressed
                time.sleep(POLL_INTERVAL)
        except OSError:
            if previous != []:
                emit([])
                previous = []
            time.sleep(0.5)
        finally:
            device.close()


if __name__ == "__main__":
    main()
