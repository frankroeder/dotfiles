#!/usr/bin/env python

import argparse
import subprocess

CHANNELS = {
  "ndrinfo": "https://www.ndr.de/resources/metadaten/audio_ssl/m3u/ndrinfo.m3u",
  "detektorfm": "https://sec-detektorfm.hoerradar.de/detektorfm-musik-mp3-128",
  "dlf": "https://st01.sslstream.dlf.de/dlf/01/128/mp3/stream.mp3",
  "jazz": "https://streaming.radio.co/s774887f7b/listen",
  "wdr3": "https://wdr-wdr3-live.icecastssl.wdr.de/wdr/wdr3/live/mp3/256/stream.mp3",
  "wacken": "https://regiocast.streamabc.net/regc-radiobobwacken2377952-mp3-192-7315957",
  "klassik": "https://live.streams.klassikradio.de/klassikradio-deutschland",
  "ndrkultur": "https://icecast.ndr.de/ndr/ndrkultur/live/mp3/128/stream.mp3",
}


def parse_args():
  parser = argparse.ArgumentParser(description="Radio player")
  parser.add_argument(
    "-c",
    "--channel",
    choices=sorted(CHANNELS),
    default="dlf",
    help="channel to play",
  )
  return parser.parse_args()


def main():
  args = parse_args()
  subprocess.run(["mpv", CHANNELS[args.channel]], check=False)


if __name__ == "__main__":
  main()
