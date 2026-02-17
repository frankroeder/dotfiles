#!/usr/bin/env bash
# toggle the visibility of an application
main(){
  if [[ $(osascript -e 'set front_app to (path to frontmost application as Unicode text)' | grep "$@") ]]; then
    osascript -e "tell application \"System Events\" to set visible of process \"$@\" to false"
  else
    open "/Applications/$@.app";
  fi
}
main "$@";
