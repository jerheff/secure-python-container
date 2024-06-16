import signal
import sys
import time

import pandas as pd


def hello(handle_signals=True):
    print(f"hello from pandas {pd.__version__}!!!")

    # Define signal handler
    def handle_signal(signum, frame):
        print(f"Received signal: {signum}")
        if signum == signal.SIGTERM:
            print("Handling SIGTERM, shutting down gracefully...")
            sys.exit(0)

    # Register signal handlers
    if handle_signals:
        signal.signal(signal.SIGTERM, handle_signal)

    print("You can test that I respond to signals like SIGTERM properly.")

    # Keep the program running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Received KeyboardInterrupt, shutting down gracefully...")
        sys.exit(0)


if __name__ == "__main__":
    hello()
