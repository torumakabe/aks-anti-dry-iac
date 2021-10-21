#!/usr/bin/env bash

APPGW_FE=your-agw-frontend-hostname-or-ip

http_err_counter=0

function trap_int() {
  printf "\nNumber of unrecoverable HTTP errors: %s\n" $http_err_counter
  exit 0
}

trap 'trap_int' 2

while true
do
  # retry 5 times with x2 backoff (1,2,4,8,16 seconds) when get transient error (HTTP 408,429,500,502,503,504)
  # https://curl.se/docs/manpage.html
  if ! curl http://${APPGW_FE}/incr -sS -f --retry 5 -m 10 -c cookie.txt -b cookie.txt;
  then
    http_err_counter=$((http_err_counter + 1))
    echo 'Unable to recover by retry'
  fi
  echo ''
  sleep 1s
done
